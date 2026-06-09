import { type ExtensionAPI, type ExtensionContext, type Theme, getAgentDir } from "@oh-my-pi/pi-coding-agent";
import { getPluginSettings } from "@oh-my-pi/pi-coding-agent/extensibility/plugins";
import { Input, matchesKey, truncateToWidth, visibleWidth, type Component, type Focusable } from "@oh-my-pi/pi-tui";
import { existsSync, mkdirSync, readFileSync, renameSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { basename, dirname, join } from "node:path";

const PACKAGE_ID = "@local/omp-prompt-stash";
const DEFAULT_STORE_FILE = "prompt-stash.json";
const STORE_VERSION = 1;
const DEFAULT_SHORTCUT = "ctrl+shift+g";
const DEFAULT_DELETE_SHORTCUTS = "ctrl+r,delete";
const DEFAULT_DELETE_ALL_SHORTCUTS = "ctrl+x";
const DEFAULT_POPUP_WIDTH = 92;
const DEFAULT_LIST_ROWS = 10;
const PADDING_X = 2;
const PADDING_Y = 1;
const ANSI_YELLOW_FG = "\u001b[33m";
const ANSI_FG_RESET = "\u001b[39m";
const FRAME = { tl: "┏", tr: "┓", bl: "┗", br: "┛", h: "━", v: "┃" } as const;
const ELLIPSIS = "…";

interface StashItem {
	id: string;
	text: string;
	createdAt: string;
}

interface StashStore {
	version: number;
	items: StashItem[];
}

interface PromptStashSettings {
	shortcut: string;
	deleteShortcuts: string[];
	deleteAllShortcuts: string[];
	storeFile: string;
	deduplicate: boolean;
	popupWidth: number;
	listRows: number;
}

function ansiYellow(text: string): string {
	return `${ANSI_YELLOW_FG}${text}${ANSI_FG_RESET}`;
}

function safeFileName(value: string): string {
	return value.replace(/[^\w.-]+/g, "_");
}

function sessionIdForContext(ctx: ExtensionContext): string {
	const id = ctx.sessionManager.getSessionId();
	if (id && id.trim()) return id;
	const file = ctx.sessionManager.getSessionFile();
	if (file) return basename(file, ".jsonl");
	return `ephemeral-${process.pid}`;
}

function settingString(raw: Record<string, unknown>, key: string, fallback: string): string {
	const value = raw[key];
	return typeof value === "string" && value.trim().length > 0 ? value.trim() : fallback;
}

function settingBoolean(raw: Record<string, unknown>, key: string, fallback: boolean): boolean {
	const value = raw[key];
	return typeof value === "boolean" ? value : fallback;
}

function settingNumber(raw: Record<string, unknown>, key: string, fallback: number): number {
	const value = raw[key];
	const parsed = typeof value === "number" ? value : typeof value === "string" ? Number(value) : Number.NaN;
	return Number.isFinite(parsed) ? parsed : fallback;
}

function shortcutList(value: string): string[] {
	const trimmed = value.trim().toLowerCase();
	if (!trimmed || trimmed === "none") return [];
	return trimmed
		.split(",")
		.map((shortcut) => shortcut.trim())
		.filter((shortcut) => shortcut.length > 0 && shortcut !== "none");
}

function sanitizeStoreFile(value: string): string {
	const file = basename(value.trim());
	return !file || file === "." || file === ".." ? DEFAULT_STORE_FILE : file;
}

async function settingsFor(cwd: string): Promise<PromptStashSettings> {
	const raw = (await getPluginSettings(PACKAGE_ID, cwd)) as Record<string, unknown>;
	const shortcut = settingString(raw, "shortcut", DEFAULT_SHORTCUT).toLowerCase();
	return {
		shortcut,
		deleteShortcuts: shortcutList(settingString(raw, "deleteShortcuts", DEFAULT_DELETE_SHORTCUTS)),
		deleteAllShortcuts: shortcutList(settingString(raw, "deleteAllShortcuts", DEFAULT_DELETE_ALL_SHORTCUTS)),
		storeFile: sanitizeStoreFile(settingString(raw, "storeFile", DEFAULT_STORE_FILE)),
		deduplicate: settingBoolean(raw, "deduplicate", true),
		popupWidth: Math.max(40, Math.floor(settingNumber(raw, "popupWidth", DEFAULT_POPUP_WIDTH))),
		listRows: Math.max(1, Math.floor(settingNumber(raw, "listRows", DEFAULT_LIST_ROWS))),
	};
}

function matchesAnyShortcut(data: string, shortcuts: readonly string[]): boolean {
	return shortcuts.some((shortcut) => matchesKey(data, shortcut));
}

function shortcutHint(shortcuts: readonly string[]): string | undefined {
	return shortcuts.length > 0 ? shortcuts.join("/") : undefined;
}

function storeDir(ctx: ExtensionContext): string {
	return join(getAgentDir(), "prompt-stash", "sessions", safeFileName(sessionIdForContext(ctx)));
}

function storePath(ctx: ExtensionContext, settings: PromptStashSettings): string {
	return join(storeDir(ctx), settings.storeFile);
}

function legacyStorePaths(ctx: ExtensionContext, settings: PromptStashSettings): string[] {
	const session = safeFileName(sessionIdForContext(ctx));
	return [
		join(homedir(), ".pi", "agent", "vstack", "sessions", session, "prompt-stash", settings.storeFile),
		join(getAgentDir(), "vstack", "sessions", session, "prompt-stash", settings.storeFile),
	];
}

function loadItems(path: string): StashItem[] {
	if (!existsSync(path)) return [];
	try {
		const parsed = JSON.parse(readFileSync(path, "utf8")) as Partial<StashStore>;
		if (!Array.isArray(parsed.items)) return [];
		return parsed.items
			.filter((item): item is StashItem => {
				return Boolean(
					item &&
						typeof item === "object" &&
						typeof (item as StashItem).id === "string" &&
						typeof (item as StashItem).text === "string" &&
						typeof (item as StashItem).createdAt === "string",
				);
			})
			.sort((a, b) => b.createdAt.localeCompare(a.createdAt));
	} catch {
		return [];
	}
}

function saveItems(path: string, items: StashItem[]): void {
	mkdirSync(dirname(path), { recursive: true, mode: 0o700 });
	const tempPath = `${path}.tmp-${process.pid}`;
	const store: StashStore = { version: STORE_VERSION, items };
	writeFileSync(tempPath, `${JSON.stringify(store, null, 2)}\n`, { encoding: "utf8", mode: 0o600 });
	renameSync(tempPath, path);
}

function mergeLegacyStores(ctx: ExtensionContext, targetPath: string, settings: PromptStashSettings): void {
	const targetItems = loadItems(targetPath);
	const byId = new Map(targetItems.map((item) => [item.id, item]));
	let foundLegacy = false;

	for (const legacyPath of legacyStorePaths(ctx, settings)) {
		if (!existsSync(legacyPath)) continue;
		const legacyItems = loadItems(legacyPath);
		if (legacyItems.length === 0) continue;
		foundLegacy = true;
		for (const item of legacyItems) {
			if (!byId.has(item.id)) byId.set(item.id, item);
		}
	}

	if (!foundLegacy) return;
	saveItems(targetPath, [...byId.values()].sort((a, b) => b.createdAt.localeCompare(a.createdAt)));
}

function makeId(): string {
	return `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 10)}`;
}

function stashPrompt(ctx: ExtensionContext, text: string, settings: PromptStashSettings): number {
	const path = storePath(ctx, settings);
	mergeLegacyStores(ctx, path, settings);
	const now = new Date().toISOString();
	const loaded = loadItems(path);
	const existing = settings.deduplicate ? loaded.filter((item) => item.text !== text) : loaded;
	const items = [{ id: makeId(), text, createdAt: now }, ...existing];
	saveItems(path, items);
	return items.length;
}

function lineCount(text: string): number {
	return Math.max(1, text.split(/\r\n|\r|\n/).length);
}

function previewText(text: string): string {
	const first = text
		.split(/\r\n|\r|\n/)
		.map((line) => line.trim())
		.find((line) => line.length > 0);
	return first ?? "(empty prompt)";
}

function padAnsi(text: string, width: number): string {
	const truncated = truncateToWidth(text, width, "");
	return `${truncated}${" ".repeat(Math.max(0, width - visibleWidth(truncated)))}`;
}

function searchable(text: string): string {
	return text.toLowerCase();
}

function panelLine(content: string, width: number): string {
	return padAnsi(content, width);
}

function selectedLine(theme: Theme, content: string, width: number): string {
	return theme.bg("selectedBg", padAnsi(theme.fg("text", content), width));
}

function popupContentWidth(width: number): number {
	return Math.max(1, width - 2 - PADDING_X * 2);
}

function framePopup(lines: string[], width: number, theme: Theme, title = "", right = ""): string[] {
	if (width < 8) return lines.map((line) => truncateToWidth(line, width, ""));

	const border = (text: string) => theme.fg("borderAccent", text);
	const contentWidth = popupContentWidth(width);
	const blank = `${border(FRAME.v)}${" ".repeat(width - 2)}${border(FRAME.v)}`;
	const top = () => {
		if (!title) return `${border(FRAME.tl)}${border(FRAME.h.repeat(width - 2))}${border(FRAME.tr)}`;
		const rightPlain = right ? ` ${right} ` : "";
		const titleBudget = Math.max(1, width - 2 - visibleWidth(rightPlain) - 1);
		const titlePlain = ` ${truncateToWidth(title, Math.max(1, titleBudget - 2), ELLIPSIS)} `;
		const fill = Math.max(1, width - 2 - visibleWidth(titlePlain) - visibleWidth(rightPlain));
		return `${border(FRAME.tl)}${theme.bold(titlePlain)}${border(FRAME.h.repeat(fill))}${right ? theme.fg("dim", rightPlain) : ""}${border(FRAME.tr)}`;
	};
	const framed = [top()];

	for (let i = 0; i < PADDING_Y; i += 1) framed.push(blank);
	for (const line of lines) {
		framed.push(`${border(FRAME.v)}${" ".repeat(PADDING_X)}${padAnsi(line, contentWidth)}${" ".repeat(PADDING_X)}${border(FRAME.v)}`);
	}
	for (let i = 0; i < PADDING_Y; i += 1) framed.push(blank);
	framed.push(`${border(FRAME.bl)}${border(FRAME.h.repeat(width - 2))}${border(FRAME.br)}`);
	return framed.map((line) => truncateToWidth(line, width, ""));
}

function renderSearchLine(searchInput: Input, width: number, theme: Theme): string {
	const prefix = " ";
	const input = searchInput.render(Math.max(1, width - visibleWidth(prefix)))[0] ?? "";
	return theme.bg("toolPendingBg", padAnsi(truncateToWidth(`${prefix}${input}`, width, ""), width));
}

function filterItems(items: StashItem[], query: string): StashItem[] {
	const trimmed = query.trim().toLowerCase();
	if (!trimmed) return items;
	return items.filter((item) => searchable(item.text).includes(trimmed));
}

async function openStashPopup(ctx: ExtensionContext): Promise<void> {
	if (!ctx.hasUI) return;

	const settings = await settingsFor(ctx.cwd);
	const path = storePath(ctx, settings);
	mergeLegacyStores(ctx, path, settings);
	let items = loadItems(path);
	if (items.length === 0) {
		ctx.ui.notify("Prompt stash is empty", "info");
		return;
	}

	let restored: string | null = null;
	restored = await ctx.ui.custom<string | null>(
		(tui, theme, _keybindings, done) => {
			const searchInput = new Input();
			searchInput.focused = true;
			let selected = 0;
			let scroll = 0;
			let confirmDeleteAll = false;

			const filtered = () => filterItems(items, searchInput.getValue());
			const clampSelection = () => {
				const count = filtered().length;
				if (count === 0) {
					selected = 0;
					scroll = 0;
					return;
				}
				selected = Math.max(0, Math.min(selected, count - 1));
				if (selected < scroll) scroll = selected;
				if (selected >= scroll + settings.listRows) scroll = selected - settings.listRows + 1;
				scroll = Math.max(0, Math.min(scroll, Math.max(0, count - settings.listRows)));
			};

			const deleteSelected = () => {
				const item = filtered()[selected];
				if (!item) return;
				items = items.filter((candidate) => candidate.id !== item.id);
				saveItems(path, items);
				clampSelection();
				tui.requestRender();
			};

			const clearAll = () => {
				items = [];
				saveItems(path, items);
				confirmDeleteAll = false;
				clampSelection();
				tui.requestRender();
			};

			const restoreSelected = () => {
				const item = filtered()[selected];
				if (!item) return;
				done(item.text);
			};

			const render = (width: number): string[] => {
				const panelWidth = Math.min(width, Math.max(40, Math.floor(settings.popupWidth)));
				const innerWidth = popupContentWidth(panelWidth);
				const results = filtered();
				clampSelection();

				const lines: string[] = [];
				lines.push(panelLine(renderSearchLine(searchInput, innerWidth, theme), innerWidth));
				lines.push(panelLine("", innerWidth));

				if (results.length === 0) {
					lines.push(panelLine(theme.fg("dim", "No matching stashed prompts"), innerWidth));
				} else {
					for (const [visibleIndex, item] of results.slice(scroll, scroll + settings.listRows).entries()) {
						const index = scroll + visibleIndex;
						const count = lineCount(item.text);
						const countText = `~${count} ${count === 1 ? "line" : "lines"}`;
						const countWidth = visibleWidth(countText);
						const rowWidth = innerWidth;
						const itemPad = " ";
						const previewWidth = Math.max(1, rowWidth - visibleWidth(itemPad) - countWidth - 1);
						const preview = truncateToWidth(previewText(item.text), previewWidth, "");
						const styledPreview = index === selected ? theme.bold(preview) : preview;
						const styledCount = index === selected ? theme.fg("text", countText) : theme.fg("dim", countText);
						const row = `${itemPad}${styledPreview}${" ".repeat(Math.max(1, rowWidth - visibleWidth(itemPad) - visibleWidth(preview) - countWidth))}${styledCount}`;
						lines.push(index === selected ? selectedLine(theme, row, innerWidth) : panelLine(row, innerWidth));
					}
				}

				const emptyRows = Math.max(0, settings.listRows - Math.max(1, Math.min(results.length, settings.listRows)));
				for (let i = 0; i < emptyRows; i += 1) lines.push(panelLine("", innerWidth));

				lines.push(panelLine("", innerWidth));
				const footerParts = [`${ansiYellow("-/=")} ${theme.fg("dim", "page")}`];
				const deleteHint = shortcutHint(settings.deleteShortcuts);
				if (deleteHint) footerParts.push(`${ansiYellow(deleteHint)} ${theme.fg("dim", "delete")}`);
				const deleteAllHint = shortcutHint(settings.deleteAllShortcuts);
				if (deleteAllHint) footerParts.push(`${ansiYellow(deleteAllHint)} ${theme.fg("dim", "delete all")}`);
				const status = confirmDeleteAll ? theme.fg("warning", "delete all stashed prompts?") : footerParts.join(theme.fg("dim", " · "));
				lines.push(panelLine(status, innerWidth));

				const frame = framePopup(lines, panelWidth, theme, "Prompt Stash", `${items.length} saved`);
				const left = " ".repeat(Math.max(0, Math.floor((width - panelWidth) / 2)));
				return frame.map((line) => truncateToWidth(`${left}${line}`, width, ""));
			};

			const component: Component & Focusable & { handleInput(data: string): void; invalidate(): void; render(width: number): string[] } = {
				get focused(): boolean {
					return searchInput.focused;
				},
				set focused(value: boolean) {
					searchInput.focused = value;
				},
				handleInput(data: string) {
					if (confirmDeleteAll) {
						if (matchesKey(data, "return") || matchesKey(data, "enter")) {
							clearAll();
							return;
						}
						if (matchesKey(data, "escape") || matchesKey(data, "ctrl+c")) {
							confirmDeleteAll = false;
							tui.requestRender();
							return;
						}
					}

					if (matchesKey(data, "escape") || matchesKey(data, "ctrl+c")) {
						done(null);
						return;
					}
					if (matchesKey(data, "return") || matchesKey(data, "enter")) {
						restoreSelected();
						return;
					}
					if (matchesKey(data, "up")) {
						selected -= 1;
						clampSelection();
						tui.requestRender();
						return;
					}
					if (matchesKey(data, "down")) {
						selected += 1;
						clampSelection();
						tui.requestRender();
						return;
					}
					if (matchesKey(data, "-") || matchesKey(data, "pageup")) {
						selected -= settings.listRows;
						clampSelection();
						tui.requestRender();
						return;
					}
					if (matchesKey(data, "=") || matchesKey(data, "pagedown")) {
						selected += settings.listRows;
						clampSelection();
						tui.requestRender();
						return;
					}
					if (matchesAnyShortcut(data, settings.deleteShortcuts)) {
						deleteSelected();
						return;
					}
					if (matchesAnyShortcut(data, settings.deleteAllShortcuts)) {
						confirmDeleteAll = items.length > 0;
						tui.requestRender();
						return;
					}
					if (matchesKey(data, "ctrl+u")) {
						searchInput.setValue("");
						selected = 0;
						clampSelection();
						tui.requestRender();
						return;
					}

					const before = searchInput.getValue();
					searchInput.handleInput(data);
					if (searchInput.getValue() !== before) {
						selected = 0;
						clampSelection();
					}
					tui.requestRender();
				},
				invalidate() {
					searchInput.invalidate();
				},
				render,
			};
			return component;
		},
		{ overlay: true },
	);

	if (restored !== null) {
		ctx.ui.setEditorText(restored);
	}
}

let stashShortcutOpen = false;

async function toggleStash(ctx: ExtensionContext): Promise<void> {
	if (stashShortcutOpen) return;
	const settings = await settingsFor(ctx.cwd);
	const text = ctx.ui.getEditorText?.() ?? "";
	if (text.trim().length > 0) {
		const count = stashPrompt(ctx, text, settings);
		ctx.ui.setEditorText("");
		ctx.ui.notify(`Stashed prompt (${count} total)`, "info");
		return;
	}

	stashShortcutOpen = true;
	try {
		await openStashPopup(ctx);
	} finally {
		stashShortcutOpen = false;
	}
}

export default async function promptStash(pi: ExtensionAPI): Promise<void> {
	const initialSettings = await settingsFor(process.cwd());
	if (initialSettings.shortcut !== "none") {
		pi.registerShortcut(initialSettings.shortcut, {
			description: "Stash current prompt or restore from prompt stash",
			handler: async (ctx) => toggleStash(ctx),
		});
	}

	pi.registerCommand("prompt-stash", {
		description: "Open the per-session prompt stash popup",
		handler: async (_args, ctx) => openStashPopup(ctx),
	});

	pi.on("session_start", async (_event, ctx) => {
		const settings = await settingsFor(ctx.cwd);
		mergeLegacyStores(ctx, storePath(ctx, settings), settings);
	});
}
