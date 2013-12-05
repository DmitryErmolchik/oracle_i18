create or replace 
package body context as

  procedure create_context as
  begin
    execute immediate 'CREATE OR REPLACE CONTEXT ' || g_context_name || ' USING context';
  end create_context;

  procedure drop_context as
  begin
    execute immediate 'DROP CONTEXT ' || g_context_name;
  end drop_context;

  procedure set_value(p_key varchar2, p_value varchar2) as
  begin
    SYS.dbms_session.set_context(g_context_name, p_key, p_value);
  end set_value;

  function get_value(p_key varchar2)
    return varchar2 as
  begin
    return SYS_CONTEXT(g_context_name, p_key);
  end get_value;

  procedure clear_value(p_key varchar2) as
  begin
    SYS.dbms_session.clear_context(namespace => g_context_name, attribute => p_key);
  end clear_value;

  procedure clear_context as
  begin
    SYS.dbms_session.clear_all_context(g_context_name);
  end clear_context;

end context;