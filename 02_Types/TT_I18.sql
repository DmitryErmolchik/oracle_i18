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
type body tr_i18 as
  constructor function tr_i18(locale varchar2, sheema_name varchar2 default null, table_name varchar2 default null, column_name varchar2, value varchar2)
    return self as result as
  begin
    self.locale := locale;
    self.sheema_name := sheema_name;
    self.table_name := table_name;
    self.column_name := column_name;
    self.value := value;
    return;
  end tr_i18;
end;

create or replace 
type tt_i18 as table of tr_i18;