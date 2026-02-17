# ---- Stage 1: Build ----
FROM maven:3.9.12-eclipse-temurin-21 AS build

WORKDIR /opt/carts

COPY pom.xml .
COPY src ./src

RUN mvn clean package -DskipTests

# ---- Stage 2: Runtime ----
FROM eclipse-temurin:21-jre

WORKDIR /run

COPY --from=build /opt/carts/target/carts.jar .

EXPOSE 80

CMD ["java", "-jar", "carts.jar", "--port=80"]

