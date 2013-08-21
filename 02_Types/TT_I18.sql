create or replace 
type tr_i18 as object (
  locale varchar2(16),
  sheema_name varchar2(32),
  table_name varchar2(32),
  column_name varchar2(32),
  value varchar2(4000),
  
  constructor function tr_i18(locale varchar2, sheema_name varchar2 default null, table_name varchar2 default null, column_name varchar2, value varchar2)
    return self as result
);

create or replace 
type tt_i18 as table of tr_i18;