create or replace 
type tr_dml as object (key varchar2(32), value varchar2(4000));

create or replace 
type tt_dml as table of tr_dml;