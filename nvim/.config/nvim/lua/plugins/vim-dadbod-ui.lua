return {
  "kristijanhusak/vim-dadbod-ui",
  dependencies = {
    {
      "tpope/vim-dadbod",
      lazy = true,
      config = function()
        vim.defer_fn(function()
          vim.cmd([[
	         function! db#adapter#snowflake#interactive(url) abort
        	   let url = db#url#parse(a:url)
        	   let cmd = (has_key(url, 'password') ? ['env', 'SNOWSQL_PWD=' . url.password] : []) +
              	   \ ["snowsql"] +
              	   \ db#url#as_argv(a:url, '-a ', '', '', '-u ', '','-d ')
        	   for [k, v] in items(url.params)
          	     if empty(v)
            	       call add(cmd, '--' . k)
          	     else
            	       call add(cmd, '--' . k . '=' . v)
          	     endif
        	   endfor
        	  return cmd
      		endfunction
               ]])
        end, 0)
      end,
    },
    { "kristijanhusak/vim-dadbod-completion", ft = { "sql", "mysql", "plsql" }, lazy = true }, -- Optional
  },
  cmd = {
    "DBUI",
    "DBUIToggle",
    "DBUIAddConnection",
    "DBUIFindBuffer",
  },
  init = function()
    -- Your DBUI configuration
    vim.g.db_ui_use_nerd_fonts = 1
  end,
}
