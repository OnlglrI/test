package com.example;

import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.SignatureAlgorithm;
import io.jsonwebtoken.security.Keys;
import lombok.Data;
import org.springframework.web.bind.annotation.*;

import java.security.Key;
import java.util.*;

@RestController
@RequestMapping("/api")
public class TestController {

    // Быстрая проверка всех либ одним запросом
    @GetMapping("/check")
    public Map<String, String> check() {
        Map<String, String> result = new LinkedHashMap<>();

        // Spring Boot
        result.put("spring-boot", "OK");

        // Spring Security (этот endpoint открыт — значит конфиг работает)
        result.put("spring-security", "OK");

        // JJWT
        try {
            Key key = Keys.secretKeyFor(SignatureAlgorithm.HS256);
            String jwt = Jwts.builder()
                    .setSubject("olympiad")
                    .setExpiration(new Date(System.currentTimeMillis() + 3600000))
                    .signWith(key)
                    .compact();
            Jwts.parserBuilder().setSigningKey(key).build().parseClaimsJws(jwt);
            result.put("jjwt", "OK");
        } catch (Exception e) {
            result.put("jjwt", "FAIL: " + e.getMessage());
        }

        // Lombok
        try {
            TestDto dto = new TestDto();
            dto.setName("test");
            dto.setValue(42);
            result.put("lombok", dto.getName() + "=" + dto.getValue() + " OK");
        } catch (Exception e) {
            result.put("lombok", "FAIL: " + e.getMessage());
        }

        // Jackson (сам факт что ответ пришёл как JSON)
        result.put("jackson", "OK");

        // JPA + H2 (приложение запустилось = H2 подключился)
        result.put("jpa+h2", "OK");

        // MySQL driver (только в classpath, не подключается)
        try {
            Class.forName("com.mysql.cj.jdbc.Driver");
            result.put("mysql-driver", "OK");
        } catch (ClassNotFoundException e) {
            result.put("mysql-driver", "FAIL: " + e.getMessage());
        }

        return result;
    }

    @GetMapping("/hello")
    public Map<String, String> hello() {
        return Map.of("message", "imports work");
    }

    @GetMapping("/token")
    public Map<String, String> token() {
        Key key = Keys.secretKeyFor(SignatureAlgorithm.HS256);
        String jwt = Jwts.builder()
                .setSubject("test")
                .setExpiration(new Date(System.currentTimeMillis() + 3600000))
                .signWith(key)
                .compact();
        return Map.of("token", jwt);
    }

    // Требует Basic auth: test/test
    @GetMapping("/secure")
    public Map<String, String> secure() {
        return Map.of("status", "authorized");
    }
}

@Data
class TestDto {
    private String name;
    private int value;
}
