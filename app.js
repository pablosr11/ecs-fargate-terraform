/*
Helmet secures Express apps by setting various HTTP headers to 
mitigate well-known security vulnerabilities.
https://helmetjs.github.io/
 */
const helmet = require("helmet");
const express = require("express");

if (!process.env.CLINIQUITA_APP_PORT || !process.env.BASIC_AUTH_USER) {
  console.log("Missing required env variables");
  process.exit(1);
}

const app = express();
const port = process.env.CLINIQUITA_APP_PORT;

const basicAuth = (req, res, next) => {
  const authHeader = req.headers.authorization;

  if (authHeader) {
    const encodedCredentials = authHeader.split(" ")[1]; // 'Basic xxxxxx'
    const credentials = Buffer.from(encodedCredentials, "base64").toString(
      "utf8"
    ); // 'user:password'
    const [username, password] = credentials.split(":");

    const basicAuthUser = process.env.BASIC_AUTH_USER;
    const basicAuthPassword = process.env.BASIC_AUTH_PASSWORD;

    if (username === basicAuthUser && password === basicAuthPassword) {
      next();
    } else {
      res.status(403);
      res.send("Invalid Credentials");
    }
  } else {
    res.status(401);
    res.setHeader("WWW-Authenticate", "Basic");
    res.send("Authorization required");
  }
};

// Expressjs recommendations
app.use(helmet());
app.disable("x-powered-by");

// health check endpoint
app.get("/amihealthy", (_req, res) => res.send("yes"));

app.get("/", basicAuth, (_req, res) =>
  res.send("Welcome! This is a secret password protected page.")
);

// Catch all 404 and error handler
app.use((_req, res, _next) =>
  res.status(404).send("Not found. We don't have this at the Cliniquita")
);

app.use((err, _req, res, _next) => {
  console.error(err.stack);
  res.status(500).send("Something's broken at the Cliniquita. We're on it!");
});

app.listen(port, () => console.log(`Server ready on port ${port}`));
