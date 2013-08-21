create or replace 
package body core as

  ---------------------------isAllColumnsExists---------------------------------
  function isAllColumnsExists(p_scheema_name varchar2 default user, p_table_name varchar2, p_value tt_dml)
    return boolean as
    l_return boolean;
    l_count number;
    l_scheema_name all_tab_columns.owner%type := upper(p_scheema_name);
    l_table_name all_tab_columns.table_name%type := upper(p_table_name);
  begin
    -- Check exists columns from p_value in table p_table_name
    select count(*)
    into l_count
    from (select column_name
          from all_tab_columns
          where owner = l_scheema_name
            and table_name = l_table_name) c
      right outer join (select * 
                        from table(p_value) 
                        where key != i18_utils.g_locale_context_code)v
        on c.column_name = i18_utils.getClearColumnName(key)
    where c.column_name is null;
    if l_count > 0
    then
      l_return := false;
    else
      l_return := true;
    end if;
    return l_return;
  end isAllColumnsExists;

  ------------------------------selectLocale------------------------------------
  function selectLocale(p_value tt_dml)
    return varchar2 as
    l_locale locales.locale_id%type;
  begin
    -- Get locale from p_value or from getLocale
    select upper(value)
    into l_locale
    from table(p_value)
    where upper(key) = i18_utils.g_locale_context_code;
    return l_locale;
  exception
    when NO_DATA_FOUND
    then
      l_locale := i18_utils.getLocale;
      return l_locale;
    when others
    then
      raise;
  end selectLocale;
  
  --------------------------insertIntoTable-------------------------------------
  /*procedure insertIntoTable(p_table_name varchar2, p_value tt_dml) as
  begin
    insertIntoTable(user, p_table_name, p_value);
  end insertIntoTable;*/

  --------------------------insertIntoTable-------------------------------------
  procedure insertIntoTable(p_scheema_name varchar2 default user, p_table_name varchar2, p_value tt_dml) as
    l_rid urowid;
  begin
    l_rid := insertIntoTable(p_scheema_name, p_table_name, p_value);
  end insertIntoTable;

  --------------------------insertIntoTable-------------------------------------
  function insertIntoTable(p_scheema_name varchar2 default user, p_table_name varchar2, p_value tt_dml)
    return urowid as
    l_insert_stmt varchar2(32767);
    l_values_stmt varchar2(32767);
    l_rid urowid;
    l_is_i18 boolean := false;
    l_locale locales.locale_id%type;
    l_i18_data tt_i18 := tt_i18();
  begin
    if not isAllColumnsExists(p_scheema_name, p_table_name, p_value)
    then
      raise_application_error(-20001, 'Wrong column name in p_val parameter');
    end if;
    
    l_locale := selectLocale(p_value);
    
    l_insert_stmt := 'INSERT INTO ' || p_scheema_name || '.' || p_table_name || '(';
    l_values_stmt := 'VALUES(';
    for l_index in p_value.first .. p_value.last
    loop
      if  (upper(p_Value(l_index).key) = i18_utils.g_locale_context_code)
      then
        -- Skip column with name equal i18_utils.g_locale_context_code
        null;
      else
        if (i18_utils.isI18Column(p_Value(l_index).key))
        then
          l_is_i18 := true;
          l_i18_data.extend();
          
          l_i18_data(l_i18_data.last) := tr_i18(locale => nvl(i18_utils.getLocaleFromColumnName(p_Value(l_index).key), l_locale),
                                                column_name => i18_utils.getClearColumnName(p_Value(l_index).key),
                                                value => p_Value(l_index).value);
          
          if (i18_utils.getClearColumnName(p_Value(l_index).key) = p_Value(l_index).key)
          then
            -- Column exists in table
            l_insert_stmt := l_insert_stmt || p_Value(l_index).key || ',';
            l_values_stmt := l_values_stmt || '''' || p_Value(l_index).value || ''',';
          end if;
        else
          l_insert_stmt := l_insert_stmt || p_Value(l_index).key || ',';
          l_values_stmt := l_values_stmt || '''' || p_Value(l_index).value || ''',';
        end if;
      end if;
    end loop;
    l_insert_stmt := rtrim(l_insert_stmt, ',') || ')';
    l_values_stmt := rtrim(l_values_stmt, ',') || ') RETURNING ROWID INTO :l_rid';

    dbms_output.put_line('Saving data to table:');
    dbms_output.put_line(l_insert_stmt || ' ' || l_values_stmt);

    execute immediate l_insert_stmt || ' ' || l_values_stmt
    using out l_rid;
    if (l_i18_data.count != 0)
    then

      dbms_output.put_line('Saving i18-data:');

      for l_index in l_i18_data.first .. l_i18_data.last
      loop
          i18_utils.setTextByRowid(p_rowid => l_rid, 
                                   p_text => l_i18_data(l_index).value, 
                                   p_column_name => l_i18_data(l_index).column_name, 
                                   p_locale => l_i18_data(l_index).locale);

          dbms_output.put_line('Locale: ' || l_i18_data(l_index).locale || ' Column: ' || l_i18_data(l_index).column_name || ' Value: ' || l_i18_data(l_index).value);

      end loop;
    end if;
    return l_rid;
/*  exception
    when others
    then
      raise;*/
  end insertIntoTable;

  ------------------------updateIntoTableById----------------------------------
  procedure updateIntoTableById(p_scheema_name varchar2 default user, p_table_name varchar2, 
                                p_value tt_dml, p_id varchar2, p_primary_key_column varchar2 default null) as
    l_rid urowid;
    l_primary_key_column all_tab_columns.column_name%type;
  begin
    if p_primary_key_column is not null
    then
      l_primary_key_column := p_primary_key_column;
    else
      l_primary_key_column := i18_utils.getPrimaryKeyColumn(p_scheema_name, p_table_name);
    end if;

    execute immediate
      'select rowid ' ||
      'from ' || p_scheema_name || '.' || p_table_name || ' ' ||
      'where ' || l_primary_key_column || '= :p_id'
    into l_rid
    using p_id;
    updateIntoTableByRowid(p_scheema_name, p_table_name, p_value, l_rid);
  end updateIntoTableById;

  -----------------------updateIntoTableByRowid---------------------------------
  procedure updateIntoTableByRowid(p_scheema_name varchar2 default user, p_table_name varchar2, p_value tt_dml, p_rowid urowid) as
    l_locale locales.locale_id%type;
    l_set_stmt varchar2(32767);
    l_where_stmt varchar2(32767);
    l_is_i18 boolean := false;
    l_i18_data tt_i18 := tt_i18();
  begin
    if not isAllColumnsExists(p_scheema_name, p_table_name, p_value)
    then
      raise_application_error(-20001, 'Wrong column name in p_val parameter');
    end if;
    l_locale := selectLocale(p_value);
    l_set_stmt := 'UPDATE ' || p_scheema_name || '.' || p_table_name || ' SET ';
    l_where_stmt := 'WHERE ROWID = :p_rowid';

    for l_index in p_value.first .. p_value.last
    loop
      if  (upper(p_Value(l_index).key) = i18_utils.g_locale_context_code)
      then
        -- Skip column with name equal i18_utils.g_locale_context_code
        null;
      else
        if (i18_utils.isI18Column(p_Value(l_index).key))
        then
          l_is_i18 := true;
          l_i18_data.extend();
          
          l_i18_data(l_i18_data.last) := tr_i18(locale => nvl(i18_utils.getLocaleFromColumnName(p_Value(l_index).key), l_locale),
                                                column_name => i18_utils.getClearColumnName(p_Value(l_index).key),
                                                value => p_Value(l_index).value);
          
          if (i18_utils.getClearColumnName(p_Value(l_index).key) = p_Value(l_index).key)
          then
            -- Column exists in table
            l_set_stmt := l_set_stmt || p_Value(l_index).key || '=' || '''' || p_Value(l_index).value || ''',';
          end if;
        else
          l_set_stmt := l_set_stmt || p_Value(l_index).key || '=' || '''' || p_Value(l_index).value || ''',';
        end if;
      end if;
    end loop;
    l_set_stmt := rtrim(l_set_stmt, ',');

    dbms_output.put_line('Updating data to table:');
    dbms_output.put_line(l_set_stmt || ' ' || l_where_stmt);

    execute immediate l_set_stmt || ' ' || l_where_stmt
    using p_rowid;
    if (l_i18_data.count != 0)
    then

      dbms_output.put_line('Updating i18-data:');

      for l_index in l_i18_data.first .. l_i18_data.last
      loop
          i18_utils.setTextByRowid(p_rowid => p_rowid, 
                                   p_text => l_i18_data(l_index).value, 
                                   p_column_name => l_i18_data(l_index).column_name, 
                                   p_locale => l_i18_data(l_index).locale);

          dbms_output.put_line('Locale: ' || l_i18_data(l_index).locale || ' Column: ' || l_i18_data(l_index).column_name || ' Value: ' || l_i18_data(l_index).value);

      end loop;
    end if;
  exception
    when others
    then
      raise;
  end updateIntoTableByRowid;

  ------------------------deleteFromTableById-----------------------------------
  procedure deleteFromTableById(p_scheema_name varchar2 default user, p_table_name varchar2, p_id number, p_primary_key_column varchar2 default null) as
    l_rid urowid;
    l_primary_key_column all_tab_columns.column_name%type;
  begin
    if p_primary_key_column is not null
    then
      l_primary_key_column := p_primary_key_column;
    else
      l_primary_key_column := i18_utils.getPrimaryKeyColumn(p_scheema_name, p_table_name);
    end if;

    dbms_output.put_line('Deleting data from table ' || p_scheema_name || '.' || p_table_name || ' where ' || l_primary_key_column || ' = ' || p_id);

    -- Delete all international text
    i18_utils.delAllTexByTableAndID(p_scheema_name => p_scheema_name, 
                                    p_table_name => p_table_name, 
                                    p_primary_key => p_id);

    execute immediate
      'delete from ' || p_scheema_name || '.' || p_table_name || ' ' ||
      'where ' || l_primary_key_column || '= :p_id'
    using p_id;
  end deleteFromTableById;

  --------------------------deleteFromTable-------------------------------------
  procedure deleteFromTableByRowid(p_rowid urowid) as
    l_scheema_name all_tab_columns.owner%type;
    l_table_name all_tab_columns.table_name%type;
    l_primary_key_column all_tab_columns.column_name%type;
  begin
    -- Delete all international text
    i18_utils.delAllTexByRowid(p_rowid => p_rowid);
    -- Delte table data
    i18_utils.getTableInfoByRowid(p_rowid, l_scheema_name, l_table_name, l_primary_key_column);
    dbms_output.put_line('Deleting data from table ' || l_scheema_name || '.' || l_table_name || ' where rowid = ' || p_rowid);
    execute immediate
      'delete from ' || l_scheema_name || '.' || l_table_name || ' ' ||
      'where rowid = :p_rowid'
    using p_rowid;
  end deleteFromTableByRowid;

end core;