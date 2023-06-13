# What is this?

Cliniko's challenge.

App is hosted at https://api.cliniquita.uk/

It is deployed on top of ECS Fargate, load balanced across two containers hosted in two availability zones in eu-west-2 (London). The app is containerized and the container hosted in AWS ECR. A small Makefile was created to improve the iteration of building and pushing the app (also updating the service when required). To facilitate communication between ECS containers and its required AWS services (ECR, S3, Cloudwatch, ECS Telemetry) I have added VPC endpoints. The SSL certificate was created and validated through AWS ACM and we verify it "only" at the application load balancer level. The domain was registered through AWS Route53 and the DNS records are managed there as well.


# Whats missing, todos, next steps.

- TLS offloading should happen at the application layer to be HIPAA compliant. Currently we are doing it at the load balancer level.
- The containers are running on a publicly available subnet. Ideally they run on a "private" subnet without a gateway.
- Security groups should be restricted to only allow traffic from the load balancer.
- No autoscaling is configured.
- The express app itself is mostly untouched. Moving away from basic auth, sanitizing the form inputs before working with them and improving error handling would be good next steps security wise.
- Missing IaC for Domain register, Certificate generation, validation etc.
- As an aggregate of above (leaky security groups, ssl up to the load balancer etc), there are "leaks" in quite a few places that would need to be addressed to meet the requirements of HIPAA.


