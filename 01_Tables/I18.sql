CREATE TABLE I18
  (
    locale_id VARCHAR2 (16) NOT NULL ,
    text_id   VARCHAR2 (512) NOT NULL ,
    text      VARCHAR2 (1024) NOT NULL
  ) ;

ALTER TABLE i18 ADD CONSTRAINT U1_i18 UNIQUE (LOCALE_ID, TEXT_ID) ;

CREATE INDEX IE1_I18 ON I18(LOCALE_ID);

CREATE INDEX IE2_I18 ON I18(TEXT_ID);