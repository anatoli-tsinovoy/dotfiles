package com.dotfiles.openinneovim;

import android.app.Activity;
import android.content.ActivityNotFoundException;
import android.content.ClipData;
import android.content.ComponentName;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.database.Cursor;
import android.net.Uri;
import android.os.Bundle;
import android.os.ParcelFileDescriptor;
import android.provider.DocumentsContract;
import android.provider.MediaStore;
import android.system.Os;
import android.view.View;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.TextView;

import java.io.File;
import java.io.IOException;

public final class MainActivity extends Activity {
    private static final String TERMUX_PACKAGE = "com.termux";
    private static final String RUN_COMMAND_PERMISSION = "com.termux.permission.RUN_COMMAND";
    private static final String RUN_COMMAND_ACTION = "com.termux.RUN_COMMAND";
    private static final String RUN_COMMAND_SERVICE = "com.termux.app.RunCommandService";
    private static final String HELPER_PATH = "/data/data/com.termux/files/home/.local/bin/termux-open-in-neovim";
    private static final String MODE_EDIT = "edit";
    private static final String MODE_LOCATION = "location";
    private static final String LOCATION_ALIAS_ACTIVITY = "com.dotfiles.openinneovim.ShowLocationActivity";
    private static final int REQUEST_RUN_COMMAND_PERMISSION = 1;
    private static final String STATE_URI = "pending_uri";
    private static final String STATE_PATH = "resolved_path";
    private static final String STATE_MODE = "mode";
    private static final String STATE_RESOLVED = "resolved";
    private static final String STATE_WAITING_PERMISSION = "waiting_permission";
    private static final String STATE_SENT = "sent";

    private TextView message;
    private Button permissionButton;
    private String pendingUri = "";
    private String candidatePath = "";
    private String mode = MODE_EDIT;
    private boolean resolved;
    private boolean waitingForPermission;
    private boolean sent;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        createUi();
        if (savedInstanceState != null && savedInstanceState.containsKey(STATE_URI)) {
            pendingUri = savedInstanceState.getString(STATE_URI, "");
            candidatePath = savedInstanceState.getString(STATE_PATH, "");
            mode = pendingUri.isEmpty()
                    ? MODE_EDIT
                    : (MODE_LOCATION.equals(savedInstanceState.getString(STATE_MODE))
                    ? MODE_LOCATION : MODE_EDIT);
            resolved = savedInstanceState.getBoolean(STATE_RESOLVED);
            waitingForPermission = savedInstanceState.getBoolean(STATE_WAITING_PERMISSION);
            sent = savedInstanceState.getBoolean(STATE_SENT);
            if (pendingUri.isEmpty()) {
                showLauncher();
            } else if (sent) {
                showStatus("The file command was already sent to Termux.", false);
            } else if (resolved) {
                resumePendingFile();
            } else {
                resolveUri(Uri.parse(pendingUri));
            }
        } else {
            handleIntent(getIntent());
        }
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        handleIntent(intent);
    }

    @Override
    protected void onSaveInstanceState(Bundle state) {
        state.putString(STATE_URI, pendingUri);
        state.putString(STATE_PATH, candidatePath);
        state.putString(STATE_MODE, pendingUri.isEmpty() ? MODE_EDIT : mode);
        state.putBoolean(STATE_RESOLVED, resolved);
        state.putBoolean(STATE_WAITING_PERMISSION, waitingForPermission);
        state.putBoolean(STATE_SENT, sent);
        super.onSaveInstanceState(state);
    }

    @Override
    protected void onResume() {
        super.onResume();
        if (!pendingUri.isEmpty() && resolved && !sent && hasRunCommandPermission()) {
            waitingForPermission = false;
            sendToTermux();
        }
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode != REQUEST_RUN_COMMAND_PERMISSION) {
            return;
        }
        waitingForPermission = false;
        if (hasRunCommandPermission()) {
            if (!pendingUri.isEmpty() && resolved) {
                sendToTermux();
            } else {
                showStatus("Termux command permission is granted. Use Open in Neovim to edit a file or Show location in Termux to reveal its location.", false);
            }
        } else {
            showStatus("Permission denied. Grant " + RUN_COMMAND_PERMISSION + " to this app in Android Settings, then reopen the file. The shared permission enables both Open in Neovim and Show location in Termux. No content was copied.", true);
        }
    }

    private void createUi() {
        int padding = (int) (24 * getResources().getDisplayMetrics().density + 0.5f);
        LinearLayout layout = new LinearLayout(this);
        layout.setOrientation(LinearLayout.VERTICAL);
        layout.setPadding(padding, padding, padding, padding);

        TextView title = new TextView(this);
        title.setText("Open in Neovim");
        title.setTextSize(24);
        layout.addView(title);

        message = new TextView(this);
        message.setTextSize(16);
        LinearLayout.LayoutParams messageParams = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        messageParams.topMargin = padding / 2;
        layout.addView(message, messageParams);

        permissionButton = new Button(this);
        permissionButton.setText("Grant Termux command permission");
        permissionButton.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                requestRunCommandPermission();
            }
        });
        LinearLayout.LayoutParams buttonParams = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        buttonParams.topMargin = padding / 2;
        layout.addView(permissionButton, buttonParams);
        setContentView(layout);
    }

    private void handleIntent(Intent intent) {
        mode = isLocationRequest(intent) ? MODE_LOCATION : MODE_EDIT;
        pendingUri = "";
        candidatePath = "";
        resolved = false;
        waitingForPermission = false;
        sent = false;

        Uri uri = incomingUri(intent);
        if (uri == null) {
            if (isFileAction(intent)) {
                showStatus("This app opens files, not text-only shares or web URLs. Share or open a file instead. No content was copied.", false);
            } else {
                showLauncher();
            }
            return;
        }
        String scheme = uri.getScheme();
        if (!"content".equalsIgnoreCase(scheme) && !"file".equalsIgnoreCase(scheme)) {
            showStatus("Only content:// and file:// file URIs are supported. Web links and text URLs are not opened. No content was copied.", false);
            return;
        }

        pendingUri = uri.toString();
        if (!isTermuxInstalled()) {
            showStatus("Termux is not installed or is unavailable. Install Termux and run scripts/termux/install-open-in-neovim.sh from the dotfiles checkout to set up both actions. No content was copied.", false);
            return;
        }
        resolveUri(uri);
    }

    private Uri incomingUri(Intent intent) {
        if (intent == null) {
            return null;
        }
        String action = intent.getAction();
        if (Intent.ACTION_VIEW.equals(action) || Intent.ACTION_EDIT.equals(action)) {
            Uri data = intent.getData();
            return data != null ? data : clipUri(intent.getClipData());
        }
        if (Intent.ACTION_SEND.equals(action)) {
            try {
                if (intent.getExtras() != null) {
                    Object stream = intent.getExtras().get(Intent.EXTRA_STREAM);
                    if (stream instanceof Uri) {
                        return (Uri) stream;
                    }
                }
            } catch (RuntimeException ignored) {
                // A malformed EXTRA_STREAM should not prevent the ClipData fallback.
            }
            return clipUri(intent.getClipData());
        }
        return null;
    }

    private Uri clipUri(ClipData clip) {
        return clip != null && clip.getItemCount() > 0 ? clip.getItemAt(0).getUri() : null;
    }

    private boolean isFileAction(Intent intent) {
        if (intent == null) {
            return false;
        }
        String action = intent.getAction();
        return Intent.ACTION_VIEW.equals(action) || Intent.ACTION_EDIT.equals(action) || Intent.ACTION_SEND.equals(action);
    }

    private boolean isLocationRequest(Intent intent) {
        if (intent == null) {
            return false;
        }
        ComponentName component = intent.getComponent();
        return component != null
                && getPackageName().equals(component.getPackageName())
                && LOCATION_ALIAS_ACTIVITY.equals(component.getClassName());
    }


    private void resolveUri(final Uri uri) {
        resolved = false;
        showStatus("Resolving the original file location. Nothing is copied or imported.", false);
        new Thread(new Runnable() {
            @Override
            public void run() {
                final String path = resolveSharedStoragePath(uri);
                runOnUiThread(new Runnable() {
                    @Override
                    public void run() {
                        if (isFinishing() || isDestroyed() || !uri.toString().equals(pendingUri)) {
                            return;
                        }
                        candidatePath = path;
                        resolved = true;
                        resumePendingFile();
                    }
                });
            }
        }, "open-in-neovim-resolver").start();
    }

    private void resumePendingFile() {
        if (!isTermuxInstalled()) {
            showStatus("Termux is not installed or is unavailable. Install Termux and run scripts/termux/install-open-in-neovim.sh from the dotfiles checkout to set up both actions.", false);
        } else if (waitingForPermission && !hasRunCommandPermission()) {
            showStatus("Waiting for Android to return the shared Termux command permission result. If no prompt is open, tap Grant Termux command permission to retry.", true);
        } else if (hasRunCommandPermission()) {
            sendToTermux();
        } else {
            requestRunCommandPermission();
        }
    }

    private void showLauncher() {
        if (!isTermuxInstalled()) {
            showStatus("Install Termux, then run scripts/termux/install-open-in-neovim.sh from the dotfiles checkout. That setup enables both Open in Neovim and Show location in Termux, using the shared Termux external-app command permission. No broad storage or internet permission is used.", false);
        } else if (!hasRunCommandPermission()) {
            showStatus("Install the Termux helper with scripts/termux/install-open-in-neovim.sh, then grant this trusted app the shared " + RUN_COMMAND_PERMISSION + " permission for both Open in Neovim and Show location in Termux. It allows arbitrary commands as your Termux user. This app starts a fixed helper without copying content or requesting storage/internet permissions.", true);
            if (!waitingForPermission) {
                requestRunCommandPermission();
            }
        } else {
            showStatus("Ready. The shared " + RUN_COMMAND_PERMISSION + " permission enables both actions. Choose Open in Neovim to edit a file or Show location in Termux to reveal its location. Only original files in shared storage are passed through; content is never copied or imported.", false);
        }
    }

    private void showStatus(String text, boolean showPermissionButton) {
        message.setText(text);
        permissionButton.setVisibility(showPermissionButton ? View.VISIBLE : View.GONE);
    }

    private void requestRunCommandPermission() {
        if (!isTermuxInstalled()) {
            showStatus("Termux is not installed or is unavailable. Install Termux and run scripts/termux/install-open-in-neovim.sh to set up both file actions.", false);
            return;
        }
        if (hasRunCommandPermission()) {
            if (!pendingUri.isEmpty() && resolved) {
                sendToTermux();
            } else {
                showLauncher();
            }
            return;
        }
        waitingForPermission = true;
        showStatus("Android will ask whether this app may run its fixed Termux helper. Grant " + RUN_COMMAND_PERMISSION + " only if you trust this app; the same permission enables Open in Neovim and Show location in Termux.", false);
        requestPermissions(new String[]{RUN_COMMAND_PERMISSION}, REQUEST_RUN_COMMAND_PERMISSION);
    }

    private boolean hasRunCommandPermission() {
        return checkSelfPermission(RUN_COMMAND_PERMISSION) == PackageManager.PERMISSION_GRANTED;
    }

    private boolean isTermuxInstalled() {
        try {
            getPackageManager().getPackageInfo(TERMUX_PACKAGE, 0);
            return true;
        } catch (PackageManager.NameNotFoundException exception) {
            return false;
        }
    }

    private void sendToTermux() {
        if (sent || pendingUri.isEmpty() || !resolved) {
            return;
        }
        if (!isTermuxInstalled()) {
            showStatus("Termux is not installed or is unavailable. Install Termux and run scripts/termux/install-open-in-neovim.sh to set up both file actions.", false);
            return;
        }
        if (!hasRunCommandPermission()) {
            requestRunCommandPermission();
            return;
        }
        if (candidatePath.isEmpty()) {
            showStatus("This provider did not expose a shared-storage file path. Forwarding the original URI to Termux without copying; its helper will explain if it cannot handle the item.", false);
        }

        Intent command = new Intent(RUN_COMMAND_ACTION);
        command.setComponent(new ComponentName(TERMUX_PACKAGE, RUN_COMMAND_SERVICE));
        command.putExtra("com.termux.RUN_COMMAND_PATH", HELPER_PATH);
        command.putExtra("com.termux.RUN_COMMAND_ARGUMENTS", new String[]{candidatePath, pendingUri, mode});
        command.putExtra("com.termux.RUN_COMMAND_BACKGROUND", false);
        command.putExtra("com.termux.RUN_COMMAND_SESSION_ACTION", "0");
        try {
            ComponentName started = startService(command);
            if (started == null) {
                showStatus("Termux did not start its command service. Run the Termux setup script and confirm external-app commands are enabled.", false);
                return;
            }
        } catch (SecurityException exception) {
            showStatus("Termux denied the command. Confirm " + RUN_COMMAND_PERMISSION + " is granted and the Termux setup script enabled external-app commands.", true);
            return;
        } catch (RuntimeException exception) {
            showStatus("Could not start Termux's foreground helper session. Confirm Termux is installed and setup is complete.", false);
            return;
        }

        sent = true;
        Intent termuxLaunch = getPackageManager().getLaunchIntentForPackage(TERMUX_PACKAGE);
        if (termuxLaunch == null) {
            showStatus("The Termux command was sent, but Android could not bring Termux to the foreground. Open Termux manually to continue.", false);
            return;
        }
        termuxLaunch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
        try {
            startActivity(termuxLaunch);
            finish();
        } catch (ActivityNotFoundException | SecurityException exception) {
            showStatus("The Termux command was sent, but Android could not bring Termux to the foreground. Open Termux manually to continue.", false);
        }
    }

    private String resolveSharedStoragePath(Uri uri) {
        String scheme = uri.getScheme();
        if ("file".equalsIgnoreCase(scheme)) {
            return canonicalSharedPath(uri.getPath());
        }
        if (!"content".equalsIgnoreCase(scheme)) {
            return "";
        }

        String authority = uri.getAuthority();
        if ("com.android.externalstorage.documents".equals(authority)) {
            String path = externalStorageDocumentPath(uri);
            if (!path.isEmpty()) {
                return path;
            }
        }
        if ("com.android.providers.downloads.documents".equals(authority)) {
            String path = rawDownloadDocumentPath(uri);
            if (!path.isEmpty()) {
                return path;
            }
        }
        String dataPath = queryDataColumn(uri);
        return dataPath.isEmpty() ? parcelFileDescriptorPath(uri) : dataPath;
    }

    private String externalStorageDocumentPath(Uri uri) {
        try {
            String id = DocumentsContract.getDocumentId(uri);
            int colon = id.indexOf(':');
            if (colon <= 0) {
                return "";
            }
            String volume = id.substring(0, colon);
            String relative = id.substring(colon + 1);
            String root;
            if ("primary".equalsIgnoreCase(volume)) {
                root = "/storage/emulated/0";
            } else if (volume.matches("[A-Fa-f0-9-]{1,128}")) {
                root = "/storage/" + volume;
            } else {
                return "";
            }
            return canonicalPathWithinRoot(root, relative);
        } catch (RuntimeException exception) {
            return "";
        }
    }

    private String rawDownloadDocumentPath(Uri uri) {
        try {
            String id = DocumentsContract.getDocumentId(uri);
            return id.startsWith("raw:") ? canonicalSharedPath(id.substring(4)) : "";
        } catch (RuntimeException exception) {
            return "";
        }
    }

    private String queryDataColumn(Uri uri) {
        try (Cursor cursor = getContentResolver().query(
                uri, new String[]{MediaStore.MediaColumns.DATA}, null, null, null)) {
            if (cursor == null || !cursor.moveToFirst()) {
                return "";
            }
            int column = cursor.getColumnIndex(MediaStore.MediaColumns.DATA);
            return column < 0 ? "" : canonicalSharedPath(cursor.getString(column));
        } catch (Exception exception) {
            return "";
        }
    }

    private String parcelFileDescriptorPath(Uri uri) {
        try (ParcelFileDescriptor descriptor = getContentResolver().openFileDescriptor(uri, "r")) {
            return descriptor == null ? "" : canonicalSharedPath(Os.readlink("/proc/self/fd/" + descriptor.getFd()));
        } catch (Exception exception) {
            return "";
        }
    }

    private String canonicalPathWithinRoot(String root, String relative) {
        if (relative == null || relative.isEmpty() || relative.startsWith("/")) {
            return "";
        }
        try {
            String canonicalRoot = new File(root).getCanonicalPath();
            String candidate = new File(root, relative).getCanonicalPath();
            return isSharedStoragePath(canonicalRoot) && isSharedStoragePath(candidate)
                    && (candidate.equals(canonicalRoot) || candidate.startsWith(canonicalRoot + "/"))
                    ? candidate : "";
        } catch (IOException | RuntimeException exception) {
            return "";
        }
    }

    private String canonicalSharedPath(String path) {
        if (path == null || path.isEmpty() || !path.startsWith("/")) {
            return "";
        }
        try {
            String canonical = new File(path).getCanonicalPath();
            return isSharedStoragePath(canonical) ? canonical : "";
        } catch (IOException | RuntimeException exception) {
            return "";
        }
    }

    private boolean isSharedStoragePath(String path) {
        return "/storage".equals(path) || path.startsWith("/storage/")
                || "/sdcard".equals(path) || path.startsWith("/sdcard/");
    }
}
