CREATE OR REPLACE PROCEDURE
    "rename_label"(old_name text, new_name text)
AS $$
BEGIN
    IF
        old_name IS NULL
    OR
        new_name IS NULL
    THEN
        RAISE EXCEPTION 'The name parameters are required!';
    END IF;
    UPDATE label
    SET name = new_name
    WHERE name = old_name;
END;
$$ LANGUAGE PLpgSQL;
