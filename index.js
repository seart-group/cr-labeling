const { Pool } = require("pg");

require("dotenv").config();
const path = require("path");
const express = require("express");
const nodeEnv = process.env.NODE_ENV || "development";
const morgan = require("morgan");
const bodyParser = require("body-parser");
const app = express();
const port = process.env.PORT || 3000;

const pool = new Pool({
    host: process.env.DB_HOST || "localhost",
    user: process.env.DB_USER || "cr_labeling_admin",
    database: process.env.DB_NAME || "cr_labeling",
    password: process.env.DB_PASS || undefined,
    port: process.env.DB_PORT || 5432,
    max: 5
});

if (nodeEnv === "development") {
    app.use(morgan("dev"));
} else {
    app.use(morgan("combined"));
}

app.set("views", "./views");
app.set("view engine", "ejs");

app.use("/", express.static(path.join(__dirname, "public")));

app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));

app.get("/reviewers", (_, res, next) => {
    pool.query("SELECT * FROM reviewer")
        .then(results => { res.status(200).send(results.rows); })
        .catch(next);
});

app.post("/reviewers", (req, res, next) => {
    const name = req.body.name;
    pool.query("INSERT INTO reviewer(name) VALUES ($1) RETURNING *", [ name ])
        .then(results => { res.status(201).send(results.rows[0]); })
        .catch(next);
});

app.get("/labels", (_, res, next) => {
    pool.query("SELECT * FROM label")
        .then(results => { res.status(200).send(results.rows); })
        .catch(next);
});

app.post("/labels", (req, res, next) => {
    const name = req.body.name;
    pool.query("INSERT INTO label(name) VALUES ($1) RETURNING *", [ name ])
        .then(results => { res.status(201).send(results.rows[0]); })
        .catch(next);
});

app.get("/", (req, res) => {
    res.redirect(req.baseUrl + "/login");
});

app.get("/login", (_, res) => {
    res.render("login");
});

app.post("/login", (req, res) => {
    const name = req.body.name;
    res.status(200).send(`Logged in as: ${name}`);
});

app.get("/error", (_, res) => {
    res.render("5XX");
});

app.get("*", (_, res) => {
    res.render("404");
});

app.listen(port, () => {
    if (nodeEnv === "development") {
        console.log(`App listening on: http://localhost:${port}`);
    }
});
