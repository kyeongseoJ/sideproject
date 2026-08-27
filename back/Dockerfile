FROM maven:3.9-eclipse-temurin-21 AS build

WORKDIR /src

# Spring Backend
COPY back ./back

# pom.xml에서 빌드 Resource로 사용하는 파일
COPY front/app/assets/config ./front/app/assets/config

WORKDIR /src/back

RUN chmod +x mvnw
RUN ./mvnw clean package -DskipTests

RUN cp "$(find target -maxdepth 1 -type f -name '*.jar' ! -name '*.original' | head -n 1)" /tmp/app.jar


FROM eclipse-temurin:21-jre

WORKDIR /app

COPY --from=build /tmp/app.jar app.jar

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "app.jar"]