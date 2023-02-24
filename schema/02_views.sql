CREATE OR REPLACE FUNCTION -- redefined later
    "complement"(category category)
    RETURNS category
AS $$ BEGIN RETURN NULL; END; $$ LANGUAGE PLpgSQL;

CREATE OR REPLACE VIEW "instance_review_candidate" AS
SELECT instance.* FROM instance
LEFT OUTER JOIN instance_review AS review ON instance.id = review.instance_id
LEFT OUTER JOIN instance_discard AS discard ON instance.id = discard.instance_id
GROUP BY instance.id, discard.instance_id
HAVING COUNT(review.id) < 2
ORDER BY
    COUNT(review.id) DESC,
    discard.instance_id IS NOT NULL DESC,
    RANDOM();

CREATE OR REPLACE VIEW "instance_review_finished" AS
SELECT
    instance.id AS id,
    instance.task AS task,
    instance.work AS work,
    CASE WHEN EVERY(review.invert_category)
        THEN COMPLEMENT(instance.category)
        ELSE instance.category
    END AS category,
    instance.input_code AS input_code,
    instance.input_nl AS input_nl,
    instance.output AS output,
    instance.target AS target
FROM instance
INNER JOIN instance_review AS review ON instance.id = review.instance_id
GROUP BY instance.id
HAVING COUNT(review.id) >= 2;

CREATE OR REPLACE VIEW "instance_review_bucket" AS
SELECT
    finished.task AS task,
    finished.work AS work,
    finished.category AS category,
    COUNT(finished.id) AS count
FROM instance_review_finished AS finished
GROUP BY finished.task, finished.work, finished.category
ORDER BY finished.task, finished.work, finished.category;

CREATE OR REPLACE VIEW "instance_review_bucket_filled" AS
SELECT bucket.task, bucket.work, bucket.category
FROM instance_review_bucket AS bucket
WHERE bucket.count > 166;

CREATE OR REPLACE VIEW "instance_review_progress" AS
SELECT reviewer.*, COUNT(review.reviewer_id) AS progress FROM reviewer
LEFT OUTER JOIN instance_review review ON reviewer.id = review.reviewer_id
GROUP BY reviewer.id
ORDER BY reviewer.id;

CREATE OR REPLACE VIEW "instance_review_conflict" AS
SELECT DISTINCT instance.* FROM instance
INNER JOIN instance_review_finished AS finished ON instance.id = finished.id
INNER JOIN instance_review AS review ON finished.id = review.instance_id
INNER JOIN instance_review_label AS review_label
    ON review.id = review_label.instance_review_id
INNER JOIN label ON label.id = review_label.label_id
GROUP BY instance.id, label.id
HAVING
    COUNT(label.id) < (
        SELECT COUNT(instance_review.id)
        FROM instance_review
        WHERE instance_review.instance_id = instance.id
    )
OR
    (
        bool_or(review.invert_category) AND NOT bool_and(review.invert_category)
    )
ORDER BY instance.id;

CREATE OR REPLACE FUNCTION
    "complement"(category category)
    RETURNS category
AS $$
BEGIN
    CASE category
        WHEN 'C' THEN RETURN 'W';
        WHEN 'W' THEN RETURN 'C';
        ELSE RETURN category;
    END CASE;
END;
$$ LANGUAGE PLpgSQL;

CREATE OR REPLACE FUNCTION
    "next_instance"(reviewer_id integer)
    RETURNS SETOF instance
AS $$
    SELECT candidate.* FROM instance_review_candidate AS candidate
    WHERE
        candidate.id NOT IN (
            SELECT review.instance_id
            FROM instance_review AS review
            WHERE review.reviewer_id = next_instance.reviewer_id
        )
    AND
        candidate.id NOT IN (
            SELECT discard.instance_id
            FROM instance_discard AS discard
            WHERE discard.reviewer_id = next_instance.reviewer_id
        )
    AND
        NOT EXISTS(
            SELECT FROM instance_review_bucket_filled AS filled
            WHERE
                filled.task = candidate.task
            AND
                filled.work = candidate.work
            AND
                filled.category = candidate.category
        )
    LIMIT 1
;
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION
    "instance_review_details"(instance_id integer)
    RETURNS TABLE (
        reviewer_id integer,
        reviewer_name text,
        invert_category boolean,
        reviewed_at timestamp,
        remarks text,
        labels text[]
    )
AS $$
    #variable_conflict use_variable
    BEGIN
        RETURN QUERY
        SELECT
            reviewer.id AS reviewer_id,
            reviewer.name AS reviewer_name,
            review.invert_category AS invert_category,
            review.reviewed_at AS reviewed_at,
            review.remarks AS remarks,
            ARRAY_AGG(label.name ORDER BY label.name) AS labels
        FROM instance_review AS review
        INNER JOIN reviewer on review.reviewer_id = reviewer.id
        INNER JOIN instance_review_label review_label
            ON review.id = review_label.instance_review_id
        INNER JOIN label ON label.id = review_label.label_id
        WHERE review.instance_id = instance_id
        GROUP BY
            reviewer.id,
            reviewer.name,
            review.invert_category,
            review.reviewed_at,
            review.remarks;
    END;
$$ LANGUAGE PLpgSQL;

CREATE OR REPLACE FUNCTION
    "instance_discard_details"(instance_id integer)
    RETURNS TABLE(
        reviewer_id integer,
        reviewer_name text,
        discarded_at timestamp,
        remarks text
    )
AS $$
    #variable_conflict use_variable
    BEGIN
        RETURN QUERY
        SELECT
            reviewer.id AS reviewer_id,
            reviewer.name AS reviewer_name,
            discard.discarded_at AS discarded_at,
            discard.remarks AS remarks
        FROM instance_discard AS discard
        INNER JOIN reviewer on discard.reviewer_id = reviewer.id
        WHERE discard.instance_id = instance_id;
    END;
$$ LANGUAGE PLpgSQL;