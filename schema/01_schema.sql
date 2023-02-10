CREATE TYPE "task" AS ENUM (
  'C&NL2C',
  'C2NL'
);

CREATE TYPE "category" AS ENUM (
  'C',
  'W'
);

CREATE TYPE "work" AS ENUM (
  '1',
  '2',
  '3',
  '4'
);

CREATE TABLE "instance" (
  "id" INTEGER GENERATED BY DEFAULT AS IDENTITY UNIQUE PRIMARY KEY,
  "task" task NOT NULL,
  "work" work NOT NULL,
  "category" category NOT NULL,
  "input_code" text,
  "input_nl" text,
  "output" text,
  "target" text
);

CREATE TABLE "reviewer" (
  "id" INTEGER GENERATED BY DEFAULT AS IDENTITY UNIQUE PRIMARY KEY,
  "name" text UNIQUE NOT NULL
);

CREATE TABLE "label" (
  "id" INTEGER GENERATED BY DEFAULT AS IDENTITY UNIQUE PRIMARY KEY,
  "name" text UNIQUE NOT NULL,
  "added_at" timestamp DEFAULT (now())
);

CREATE TABLE "instance_review" (
  "id" INTEGER GENERATED BY DEFAULT AS IDENTITY UNIQUE PRIMARY KEY,
  "instance_id" integer,
  "reviewer_id" integer,
  "is_interesting" boolean NOT NULL DEFAULT false,
  "invert_category" boolean NOT NULL DEFAULT false,
  "reviewed_at" timestamp DEFAULT (now()),
  "remarks" text
);

CREATE TABLE "instance_discard" (
  "instance_id" integer,
  "reviewer_id" integer,
  "discarded_at" timestamp DEFAULT (now()),
  "remarks" text,
  PRIMARY KEY ("instance_id", "reviewer_id")
);

CREATE TABLE "instance_review_label" (
  "instance_review_id" integer,
  "label_id" integer,
  PRIMARY KEY ("instance_review_id", "label_id")
);

CREATE UNIQUE INDEX ON "instance_review" ("instance_id", "reviewer_id");

ALTER TABLE "instance_review" ADD FOREIGN KEY ("instance_id") REFERENCES "instance" ("id");
ALTER TABLE "instance_review" ADD FOREIGN KEY ("reviewer_id") REFERENCES "reviewer" ("id");
ALTER TABLE "instance_discard" ADD FOREIGN KEY ("instance_id") REFERENCES "instance" ("id");
ALTER TABLE "instance_discard" ADD FOREIGN KEY ("reviewer_id") REFERENCES "reviewer" ("id");
ALTER TABLE "instance_review_label" ADD FOREIGN KEY ("instance_review_id") REFERENCES "instance_review" ("id");
ALTER TABLE "instance_review_label" ADD FOREIGN KEY ("label_id") REFERENCES "label" ("id");
