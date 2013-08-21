create or replace 
package body i18_utils as

  ----------------------------getPrimaryKeyColumn-------------------------------
  function getPrimaryKeyColumn(p_scheema_name varchar2 default user, p_table_name varchar2) 
    return varchar2 as
    l_primary_key_column all_tab_columns.column_name%type;
    l_scheema_name all_tab_columns.owner%type := upper(p_scheema_name);
    l_table_name all_tab_columns.table_name%type := upper(p_table_name);
  begin
    --Getting primary key column
    select col.column_name
    into l_primary_key_column
    from all_objects o
      join all_tab_columns col
        on o.object_name = col.table_name
          and o.owner = col.owner
      join all_constraints c
        on c.table_name = col.table_name
          and c.owner = col.owner
      join all_cons_columns cc
        on c.constraint_name = cc.constraint_name
          and col.column_name = cc.column_name
          and cc.owner = col.owner
    where c.table_name = l_table_name
      and c.owner = l_scheema_name
      and c.constraint_type = 'P';
    return l_primary_key_column;
  exception
    when others
    then
      raise;
  end getPrimaryKeyColumn;

  -------------------------getTavleInfoFromRowid--------------------------------
  procedure getTableInfoByRowid(p_rowid urowid, p_scheema_name out varchar2, p_table_name out varchar2, p_primary_key_column out varchar2) as
    l_object_id number;
  begin
    l_object_id := dbms_rowid.rowid_object(to_char(p_rowid));

    select col.owner, col.table_name, col.column_name
    into p_scheema_name, p_table_name, p_primary_key_column
    from all_objects o
      join all_tab_columns col
        on o.object_name = col.table_name
          and o.owner = col.owner
      join all_constraints c
        on c.table_name = col.table_name
          and c.owner = col.owner
      join all_cons_columns cc
        on c.constraint_name = cc.constraint_name
          and col.column_name = cc.column_name
          and cc.owner = col.owner
    where o.object_id = l_object_id
      and c.constraint_type = 'P';
  end getTableInfoByRowid;

  -----------------------------getText------------------------------------------
  function getText(p_text_id varchar2, p_locale varchar2 default null)
    return varchar2
  as
    l_return varchar2(4000);
    l_locale_id locales.locale_id%type;
  begin
    -- If locale is null, then take locale from getLocale
    if p_locale is null
    then
      l_locale_id := getLocale;
    else
      l_locale_id := upper(p_locale);
    end if;
    
    select text
    into l_return
    from (select text, lvl, min(lvl) over(partition by i.text_id) as minlvl
          from (select level as lvl, locale_id
                from locales
                start with locale_id = l_locale_id
                connect by prior up_id = locale_id) l
            join i18 i
              on l.locale_id = i.locale_id
          where i.text_id = p_text_id)
    where lvl = minlvl;
    return l_return;
  end getText;

  -----------------------------getTextByRowId------------------------------------------
  function getTextByRowId(p_rowid urowid, p_column_name varchar2 default null, p_locale varchar2 default null)
    return varchar2
  as
    l_return varchar2(4000);
  begin
    if p_locale is null
    then
      return getText(genTextIdByRowid(p_rowid, p_column_name), getLocale);
    else
      return getText(genTextIdByRowid(p_rowid, p_column_name), p_locale);
    end if;
  end getTextByRowId;

  ------------------------getTextByTableData------------------------------------
  function getTextByTableData(p_scheema_name varchar2 default user, p_table_name varchar2, p_column_name varchar2 default null, p_primary_key varchar2, p_locale varchar2 default null)
    return varchar2
  as
    l_text_id varchar2(4000);
    l_scheema_name all_tab_columns.owner%type := upper(p_scheema_name);
    l_table_name all_tab_columns.table_name%type := upper(p_table_name);
    l_primary_key_column all_tab_columns.column_name%type;
    l_column_name all_tab_columns.column_name%type;
  begin
    l_primary_key_column := getPrimaryKeyColumn(p_scheema_name => l_scheema_name,  p_table_name => l_table_name);
    if p_column_name is null
    then
      execute immediate 
        'select i18_utils.genTextIdByTableData(:l_scheema_name, :l_table_name, ' ||
                                       '(select column_name ' ||
                                        'from all_tab_columns ' ||
                                        'where owner = :l_scheema_name ' ||
                                          'and table_name = :l_table_name ' ||
                                          'and column_name like :column_suffix escape ''!''), ' || 
                                         l_primary_key_column || ') ' ||
        'from ' || l_scheema_name || '.' || l_table_name || ' ' ||
        'where ' || l_primary_key_column || ' = :p_primary_key'
        into l_text_id
        using l_scheema_name, l_table_name, l_scheema_name, l_table_name, '%!_' || g_i18_suffix, p_primary_key;
    else
      l_text_id := genTextIdByTableData(p_scheema_name => l_scheema_name,
                                        p_table_name => l_table_name,
                                        p_column_name => p_column_name,
                                        p_primary_key => p_primary_key);
    end if;
    if p_locale is null
    then
      return getText(l_text_id, getLocale);
    else
      return getText(l_text_id, p_locale);
    end if;
  end getTextByTableData;

  -------------------------getTextExtended--------------------------------------
  function getTextExtended(p_text_id varchar2, p_locale varchar2 default null)
    return varchar2
  as
    l_return varchar2(4000);
    l_primary_key varchar2(256);
    l_primary_key_column user_tab_columns.column_name%type;
    l_column_name varchar2(32);
    l_table_name varchar2(32);
    l_scheema_name varchar2(32);
  begin
    l_return := getText(p_text_id, p_locale);
    return l_return;
  exception
    when NO_DATA_FOUND
    then
      --No data in internationalization column, selecting data from core table
      getDataFromTextId(p_text_id, l_scheema_name, l_table_name, l_column_name, l_primary_key);

      l_primary_key_column := getPrimaryKeyColumn(l_scheema_name, l_table_name);

      execute immediate
      'select ' || l_column_name || ' ' ||
      'from ' || l_table_name || ' ' ||
      'where ' || l_primary_key_column || '= :l_primary_key'
      into l_return
      using l_primary_key;
      return l_return;
  end getTextExtended;

  -----------------------------setText------------------------------------------
  procedure setText(p_text_id varchar2, p_text varchar2, p_locale varchar2) as
  begin
      merge into i18 t
      using (select p_locale as locale_id, p_text_id as text_id, p_text as text from dual) s
      on (t.locale_id = s.locale_id
        and t.text_id = s.text_id)
      when matched
        then
          update set t.text = s.text
      when not matched
        then
          insert (locale_id, text_id, text)
          values (s.locale_id, s.text_id, s.text);
  end setText;

  -----------------------------setText------------------------------------------
  procedure setText(p_text_id varchar2, p_text varchar2) as
  begin
    setText(p_text_id => p_text_id, p_text => p_text, p_locale => getLocale);
  end setText;

  --------------------------setTextByRowid--------------------------------------
  procedure setTextByRowid(p_rowid urowid, p_text varchar2, p_locale varchar2) as
  begin
    setText(p_text_id => genTextIdByRowid(p_rowid), p_text => p_text, p_locale => p_locale);
  end setTextByRowid;

  --------------------------setTextByRowid--------------------------------------
  procedure setTextByRowid(p_rowid urowid, p_text varchar2, p_column_name varchar2, p_locale varchar2) as
  begin
    setText(p_text_id => genTextIdByRowid(p_rowid, p_column_name), p_text => p_text, p_locale => p_locale);
  end setTextByRowid;

  --------------------------setTextByRowid--------------------------------------
  procedure setTextByRowid(p_rowid urowid, p_text varchar2) as
  begin
    setText(p_text_id => genTextIdByRowid(p_rowid), p_text => p_text, p_locale => getLocale);
  end setTextByRowid;

  --------------------------setTextByRowid--------------------------------------
  procedure setTextByRowid(p_rowid urowid, p_text varchar2, p_column_name varchar2) as
  begin
    setText(p_text_id => genTextIdByRowid(p_rowid, p_column_name), p_text => p_text, p_locale => getLocale);
  end setTextByRowid;

  --------------------------------delText---------------------------------------
  procedure delText(p_text_id varchar2, p_locale_id varchar2 default null) as
  begin
    if p_locale_id is not null
    then
        delete from i18
        where text_id = p_text_id
          and locale_id = p_locale_id;
    else
        delete from i18
        where text_id = p_text_id;
    end if;
  end delText;

  --------------------------------delText---------------------------------------
  procedure delText(p_scheema_name varchar2 default user, p_table_name varchar2, p_column_name varchar2, p_primary_key varchar2, p_locale_id varchar2 default null) as
  begin
    delText(genTextIdByTableData(p_scheema_name, p_table_name, p_column_name, p_primary_key), p_locale_id);
  end delText;

  ----------------------------delTextByRowId------------------------------------
  procedure delTextByRowId(p_rowid urowid, p_coumn_name varchar2 default null, p_locale_id varchar2 default null) as
  begin
    delText(genTextIdByRowId(p_rowid, p_coumn_name), p_locale_id);
  end delTextByRowId;

  -------------------------delAllTexByTableAndId--------------------------------
  procedure delAllTexByTableAndId(p_scheema_name varchar2 default user, p_table_name varchar2, p_primary_key varchar2) as
    l_template i18.text_id%type;
  begin
    l_template := genTextIdByTableData(p_scheema_name, p_table_name, '%', p_primary_key);
    SYS.dbms_output.put_line(l_template);
    delete from i18
    where text_id like l_template;
  end delAllTexByTableAndId;

  ----------------------------delAllTexByRowid----------------------------------
  procedure delAllTexByRowid(p_rowid urowid) as
    l_scheema_name all_tab_columns.owner%type;
    l_table_name all_tab_columns.table_name%type;
    l_primary_key_column all_tab_columns.column_name%type;
    l_primary_key i18.text_id%type;
  begin
    getTableInfoByRowid(p_rowid, l_scheema_name, l_table_name, l_primary_key_column);
    execute immediate
      'select ' || l_primary_key_column || ' ' ||
      'from ' || l_scheema_name || '.' || l_table_name || ' ' ||
      'where rowid = :p_rowid'
    into l_primary_key
    using p_rowid;
    delAllTexByTableAndId(p_scheema_name => l_scheema_name, p_table_name => l_table_name, p_primary_key => l_primary_key);
  end delAllTexByRowid;

  ----------------------genTextIdFromTblData-------------------------------------
  function genTextIdByTableData(p_scheema_name varchar2, p_table_name varchar2, p_column_name varchar2, p_primary_key varchar2)
    return varchar2 as
  begin
    return upper(p_scheema_name || g_text_id_separator || p_table_name || g_text_id_separator || p_column_name || g_text_id_separator || p_primary_key);
  end genTextIdByTableData;

  ------------------------genTextIdByRowid--------------------------------------
  function genTextIdByRowid(p_rowid urowid, p_column_name varchar2 default null)
    return varchar2
  as
    l_table_name varchar2(32);
    l_primary_key_column varchar2(32);
    l_primary_key varchar2(256);
    l_column_name varchar2(32);
    l_object_id number;
    l_scheema_name varchar2(32);
    l_return varchar(256);
  begin
    getTableInfoByRowid(p_rowid, l_scheema_name, l_table_name, l_primary_key_column);

    if (l_table_name is not null) and (l_primary_key_column is not null)
    then
      if p_column_name is null
      then
        execute immediate 
          'select i18_utils.genTextIdByTableData(:l_scheema_name, :l_table_name, ' ||
                                         '(select column_name ' ||
                                          'from all_tab_columns ' ||
                                          'where owner = :l_scheema_name ' ||
                                            'and table_name = :l_table_name ' ||
                                            'and column_name like :column_suffix escape ''!''), ' || 
                                           l_primary_key_column || ') ' ||
          'from ' || l_table_name || ' ' ||
          'where rowid = :p_rowid'
          into l_return
          using l_scheema_name, l_table_name, l_scheema_name, l_table_name, '%!_' || g_i18_suffix, p_rowid;
      else
        execute immediate 
          'select i18_utils.genTextIdByTableData(:l_scheema_name, :l_table_name, :p_column_name, ' || l_primary_key_column || ') ' ||
          'from ' || l_scheema_name || '.' || l_table_name || ' ' ||
          'where rowid = :p_rowid'
        into l_return
        using l_scheema_name, l_table_name, p_column_name, p_rowid;
      end if;
      return l_return;
    else
      raise NO_DATA_FOUND;
    end if;
    return null;
    exception
      when others then raise;
  end genTextIdByRowid;

  ---------------------getPrimatyKeyFromTextId-----------------------------------
  function getPrimatyKeyFromTextId(p_text_id varchar2)
    return varchar2 as
    l_return varchar2(512);
  begin
    l_return := regexp_substr(p_text_id, g_text_id_separator || '[[:alnum:]\_]+', 1, 3);
    return substrc(l_return, 2, lengthc(l_return)-1);
  end getPrimatyKeyFromTextId;

  ------------------------getColumnFromTextId-------------------------------------
  function getColumnFromTextId(p_text_id varchar2)
    return varchar2 as
    l_return varchar2(512);
  begin
    l_return := regexp_substr(p_text_id, g_text_id_separator || '[[:alnum:]\_]+', 1, 2);
    return substrc(l_return, 2, lengthc(l_return)-1);
  end getColumnFromTextId;

  -----------------------getTableFromTextId-------------------------------------
  function getTableFromTextId(p_text_id varchar2)
    return varchar2 as
    l_return varchar2(512);
  begin
    l_return := regexp_substr(p_text_id, g_text_id_separator || '[[:alnum:]\_]+', 1, 1);
    return substrc(l_return, 2, lengthc(l_return)-1);
  end getTableFromTextId;

  -----------------------getScheemaFromTextId-------------------------------------
  function getScheemaFromTextId(p_text_id varchar2)
    return varchar2 as
    l_return varchar2(512);
  begin
    l_return := regexp_substr(p_text_id, '[[:alnum:]\_]+' || g_text_id_separator, 1, 1);
    return substrc(l_return, 1, lengthc(l_return)-1);
  end getScheemaFromTextId;


  ------------------------getDataFromTextId-------------------------------------
  procedure getDataFromTextId(p_text_id varchar2,
                              p_scheema_name out varchar2,
                              p_table_name out varchar2,
                              p_column_name out varchar2,
                              p_primary_key out varchar2) as
  begin
    p_scheema_name := getScheemaFromTextId(p_text_id);
    p_table_name := getTableFromTextId(p_text_id);
    p_column_name := getColumnFromTextId(p_text_id);
    p_primary_key := getPrimatyKeyFromTextId(p_text_id);
  end getDataFromTextId;

  -----------------------------getLocale---------------------------------------
  function getLocale
    return varchar2 as
    l_return locales.locale_id%type;
  begin
    l_return := context.get_value(g_locale_context_code);
    if (l_return is null)
    then
      l_return := userenv('LANG');
    end if;
    return upper(l_return);
  end getLocale;

  ------------------------getLocaleFromColumnName-------------------------------
  function getLocaleFromColumnName(p_column_name varchar2)
    return varchar2 as
  begin
    return substrc(regexp_substr(p_column_name, '\_' || g_i18_suffix || '/\w{'|| g_locale_min_length || ',' || g_locale_max_length || '}'),
                   length('\_' || g_i18_suffix || '/'));
  end getLocaleFromColumnName;

  ------------------------getLocaleFromColumnName-------------------------------
  function getClearColumnName(p_column_name varchar2)
    return varchar2 as
    l_suffix_lang varchar2(32);
    l_suffix_lang_length number;
    l_column_name user_tab_columns.column_name%type;
    l_return user_tab_columns.column_name%type;
  begin
    l_column_name := upper(p_column_name);
    l_suffix_lang := regexp_substr(l_column_name, '\_' || g_i18_suffix || '/\w{'|| g_locale_min_length || ',' || g_locale_max_length || '}');
    if (l_suffix_lang is not null)
    then
      l_suffix_lang_length := length(l_suffix_lang) - 1 - length(g_i18_suffix);
      l_return := substrc(l_column_name, 1, length(l_column_name) - l_suffix_lang_length);
    else
      l_return := l_column_name;
    end if;
    return l_return;
  end getClearColumnName;
  
  -------------------------isLocaleInColumnName---------------------------------
  function isLocaleInColumnName(p_column_name varchar2)
    return boolean as
    l_return boolean := false;
  begin
    if regexp_like(p_column_name, '\_' || g_i18_suffix || '/\w{'|| g_locale_min_length || ',' || g_locale_max_length || '}')
    then
      l_return := true;
    end if;
    return l_return;
  end isLocaleInColumnName;

  -------------------------isLocaleInColumnName---------------------------------
  function isI18Column(p_column_name varchar2)
    return boolean as
    l_return boolean := false;
  begin
    if regexp_like(p_column_name, '/\w{'|| g_locale_min_length || ',' || g_locale_max_length || '}') or
       regexp_like(p_column_name, '\_' || g_i18_suffix || '(/\w{'|| g_locale_min_length || ',' || g_locale_max_length || '})?')
    then
      l_return := true;
    end if;
    return l_return;
  end isI18Column;


end i18_utils;