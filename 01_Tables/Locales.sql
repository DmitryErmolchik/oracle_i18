CREATE TABLE Locales
  (
    locale_id VARCHAR2 (16) NOT NULL ,
    up_id     VARCHAR2 (16) NULL ,
    name      VARCHAR2 (64) NOT NULL
  ) ;
ALTER TABLE Locales ADD CONSTRAINT PK_Languages PRIMARY KEY
(
  locale_id
)
;

CREATE OR REPLACE TRIGGER upper_locale_id 
before insert or update on locales
for each row
begin
  :new.locale_id := upper(:new.locale_id);
  :new.up_id := upper(:new.up_id);
end;