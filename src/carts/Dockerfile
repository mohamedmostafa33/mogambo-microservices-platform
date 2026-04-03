FROM maven:3.9.12-eclipse-temurin-21 AS deps

WORKDIR /opt/carts

# Cache Maven dependencies before copying source code.
COPY pom.xml ./
RUN mvn -B -ntp dependency:go-offline

FROM maven:3.9.12-eclipse-temurin-21 AS build

WORKDIR /opt/carts

COPY --from=deps /root/.m2 /root/.m2
COPY pom.xml ./
COPY src ./src

RUN mvn -B -ntp -DskipTests clean package

FROM eclipse-temurin:21-jre AS runtime

RUN apt-get update \
	&& rm -rf /var/lib/apt/lists/* \
	&& groupadd --system --gid 10001 carts \
	&& useradd --system --uid 10001 --gid carts --create-home --home-dir /home/carts carts

WORKDIR /opt/carts

COPY --from=build /opt/carts/target/carts.jar ./carts.jar

RUN chown -R carts:carts /opt/carts

USER carts

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "/opt/carts/carts.jar"]
CMD ["--port=8080"]

