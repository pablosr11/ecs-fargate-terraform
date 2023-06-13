
Our developers have just finished writing an amazing NodeJS API. They need your help getting it deployed to AWS ECS Fargate. Please open a pull request to add the infrastructure as code needed to deploy this service to AWS using IaC tooling of your choice.

# Requirements

- Deploy the service to your own AWS account ECS Fargate using IaC tooling of your choice. If you have a domain you can use for the service, feel free to use that, or register a domain for the purpose of this test.
- The service should be fully end-to-end encrypted to comply with HIPAA regulations.
- Feel free to modify the existing code as needed for security best practices.
- The service should be available at `https://api.{your-domain-or-subdomain}` or similar.

# When complete:

Open a pull request in this repo we've provided you https://github.com/redguava/2023-ops-hiring-pablo, do not open a PR in the upstream repo that is the source of your forked repo.
Let us know what URL the service is available at.
Optionally provide a summary of why you made the choices you made.
Don’t forget to let us know you’re finished.

# Docker build

```
docker build -t rg-ops .
docker run -p 3000:3000 rg-ops
```
