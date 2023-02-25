CREATE OR REPLACE VIEW "label_assigned_to_instances" AS
SELECT
    label.id AS label_id,
    label.name AS label_name,
    instance.id AS instance_id,
    instance.task AS instance_task,
    instance.work AS instance_work,
    CASE WHEN review.invert_category
        THEN COMPLEMENT(instance.category)
        ELSE instance.category
    END AS instance_category
FROM label
         LEFT OUTER JOIN instance_review_label review_label ON label.id = review_label.label_id
         LEFT OUTER JOIN instance_review review ON review.id = review_label.instance_review_id
         LEFT OUTER JOIN instance ON instance.id = review.instance_id
ORDER BY instance_id NULLS LAST;

-- CREATE OR REPLACE VIEW "instance_review_label_by_reviewer" AS
-- SELECT
--     label.id AS label_id,
--     label.name AS label_name,
--     instance.id AS instance_id,
--     instance.task AS instance_task,
--     instance.work AS instance_work,
--     CASE WHEN review.invert_category
--         THEN COMPLEMENT(instance.category)
--         ELSE instance.category
--     END AS instance_category,
--     instance.input_code AS instance_input_code,
--     instance.input_nl AS instance_input_nl,
--     instance.output AS instance_output,
--     instance.target AS instance_target,
--     reviewer.name AS reviewer
-- FROM label
-- LEFT OUTER JOIN instance_review_label review_label ON label.id = review_label.label_id
-- LEFT OUTER JOIN instance_review review ON review.id = review_label.instance_review_id
-- LEFT OUTER JOIN instance ON instance.id = review.instance_id
-- LEFT OUTER JOIN reviewer ON reviewer.id = review.reviewer_id
-- WHERE instance.id IS NOT NULL;

CREATE OR REPLACE VIEW "instance_review_label_by_reviewer" AS
SELECT
    label.id AS label_id,
    label.name AS label_name,
    instance.id AS instance_id,
    instance.task AS instance_task,
    instance.work AS instance_work,
    CASE WHEN review.invert_category
        THEN COMPLEMENT(instance.category)
        ELSE instance.category
    END AS instance_category,
    instance.input_code AS instance_input_code,
    instance.input_nl AS instance_input_nl,
    instance.output AS instance_output,
    instance.target AS instance_target,
    reviewer.name AS reviewer
FROM label
INNER JOIN instance_review_label review_label ON label.id = review_label.label_id
INNER JOIN instance_review review ON review.id = review_label.instance_review_id
INNER JOIN instance ON instance.id = review.instance_id
INNER JOIN reviewer ON reviewer.id = review.reviewer_id;

CREATE OR REPLACE VIEW "label_category_distribution" AS
WITH total_correct AS (
    SELECT COUNT(*)
    FROM label_assigned_to_instances
    WHERE instance_category = 'C'
), total_wrong AS (
    SELECT COUNT(*)
    FROM label_assigned_to_instances
    WHERE instance_category = 'W'
)
SELECT
    label_id,
    label_name,
    SUM(CASE WHEN instance_category = 'C' THEN 1 ELSE 0 END) AS in_correct,
    SUM(CASE WHEN instance_category = 'C' THEN 1 ELSE 0 END)::float / (SELECT * FROM total_correct) AS percentage_correct,
    SUM(CASE WHEN instance_category = 'W' THEN 1 ELSE 0 END) AS in_wrong,
    SUM(CASE WHEN instance_category = 'W' THEN 1 ELSE 0 END)::float / (SELECT * FROM total_wrong) AS percentage_wrong
FROM label_assigned_to_instances
GROUP BY label_id, label_name
ORDER BY percentage_wrong DESC, percentage_correct DESC;
