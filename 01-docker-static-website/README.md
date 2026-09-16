# Dockerized Static Website

A static website (HTML/CSS/JS) served through Nginx, packaged as a Docker image built on `nginx:alpine`.

## Goal

Practice the fundamentals of containerization before moving on to orchestrating infrastructure around it: writing a minimal, correct Dockerfile, understanding image layering, and choosing a base image with size and attack surface in mind.

## Project structure

```
.
├── Dockerfile
├── website/
│   ├── index.html
│   ├── css/
│   │   └── style.css
│   └── js/
│       └── script.js
└── reference/
    ├── Dockerfile
    └── docker-compose.yml
```

`website/` holds the static site being served. `reference/` is a second implementation of the same idea using `docker-compose`, kept side by side for comparison — useful when the project grows to more than one container (see the Terraform project, where this site is deployed to a real EC2 instance).

## The Dockerfile

```dockerfile
FROM nginx:alpine

COPY website/ /usr/share/nginx/html/

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
```

Two deliberate choices worth explaining:

- **`nginx:alpine` as the base image.** Alpine-based images are a fraction of the size of the default Debian-based ones (tens of MB instead of hundreds), which means faster builds, faster pulls, and a smaller attack surface — fewer packages installed means fewer potential vulnerabilities. For a static file server, there's no need for anything heavier.
- **`daemon off;`.** Nginx normally forks into the background and exits its parent process, which is the opposite of what a container needs — a container's lifecycle is tied to its main process (PID 1). Running Nginx in the foreground keeps the container alive for as long as Nginx itself is running, and lets Docker correctly detect if it crashes.

## Build and run

```bash
docker build -t static-website .
docker run -d -p 8080:80 --name static-website static-website
```

The site is then available at `http://localhost:8080`.

To run it via the `docker-compose` variant instead:

```bash
cd reference
docker compose up -d
```

## Next step

This image is the one later pushed to the ECR repository provisioned in [`02-terraform-aws-infra`](../02-terraform-aws-infra) and run on the EC2 instance created there.
