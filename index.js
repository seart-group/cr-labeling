require("dotenv").config();
const express = require("express");
const nodeEnv = process.env.NODE_ENV || "development";
const logger = require("morgan");
const bodyParser = require("body-parser");
const app = express();
const port = process.env.PORT || 3000;

if (nodeEnv === "development") {
    app.use(logger("dev"));
} else {
    app.use(logger("combined"));
}

app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));

app.get("/", function (req, res) {
    res.send("Hello World");
});

app.post("/login", function (req, res) {
    const name = req.body.name;
    res.status(200);
    res.send(`Logged in as: ${name}`);
});

app.listen(port);
