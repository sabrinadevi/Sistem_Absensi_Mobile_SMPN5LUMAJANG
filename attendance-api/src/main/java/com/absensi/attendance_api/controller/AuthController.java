package com.absensi.attendance_api.controller;

import com.absensi.attendance_api.model.User;
import com.absensi.attendance_api.repository.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.Map;
import java.util.Optional;

@RestController
@RequestMapping("/api")
@CrossOrigin(origins = "*")
public class AuthController {

    @Autowired
    private UserRepository userRepository;

    @PostMapping("/register")
    public ResponseEntity<?> register(@RequestBody Map<String, String> params) {
        Map<String, Object> response = new HashMap<>();
        try {
            String username = params.get("username");
            String password = params.get("password");
            String role = params.get("role");
            String nama = params.getOrDefault("nama", username);
            
            if (userRepository.findByUsername(username).isPresent()) {
                response.put("status", "error");
                response.put("message", "Username sudah digunakan");
                return ResponseEntity.badRequest().body(response);
            }

            User user = new User();
            user.setNama(nama);
            user.setUsername(username);
            user.setPassword(password);
            user.setRole(role);
            
            userRepository.save(user);
            
            response.put("status", "success");
            response.put("message", "Pendaftaran Berhasil");
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            response.put("status", "error");
            response.put("message", "Terjadi kesalahan: " + e.getMessage());
            return ResponseEntity.status(500).body(response);
        }
    }

    @PostMapping("/login")
    public ResponseEntity<?> login(@RequestBody Map<String, String> params) {
        String username = params.get("username");
        String password = params.get("password");

        Map<String, Object> response = new HashMap<>();
        Optional<User> userOpt = userRepository.findByUsername(username);

        if (userOpt.isPresent() && userOpt.get().getPassword().equals(password)) {
            User user = userOpt.get();
            response.put("status", "success");
            response.put("message", "Login Berhasil");
            
            Map<String, Object> userData = new HashMap<>();
            userData.put("id", user.getId());
            userData.put("username", user.getUsername());
            userData.put("nama_lengkap", user.getNama());
            userData.put("role", user.getRole());
            
            response.put("data", userData);
            return ResponseEntity.ok(response);
        }

        response.put("status", "error");
        response.put("message", "Username atau Password salah");
        return ResponseEntity.status(401).body(response);
    }

    @GetMapping("/users")
    public ResponseEntity<?> getAllUsers() {
        return ResponseEntity.ok(userRepository.findAll());
    }

    @PutMapping("/users/update/{id}")
    public ResponseEntity<?> updateUser(@PathVariable Integer id, @RequestBody Map<String, String> params) {
        Map<String, Object> response = new HashMap<>();
        return userRepository.findById(id).map(user -> {
            if (params.containsKey("nama")) user.setNama(params.get("nama"));
            if (params.containsKey("username")) user.setUsername(params.get("username"));
            if (params.containsKey("password")) user.setPassword(params.get("password"));
            if (params.containsKey("role")) user.setRole(params.get("role"));
            
            userRepository.save(user);
            response.put("status", "success");
            response.put("message", "User berhasil diperbarui");
            return ResponseEntity.ok(response);
        }).orElse(ResponseEntity.notFound().build());
    }

    @DeleteMapping("/users/delete/{id}")
    public ResponseEntity<?> deleteUser(@PathVariable Integer id) {
        userRepository.deleteById(id);
        Map<String, Object> response = new HashMap<>();
        response.put("status", "success");
        response.put("message", "User berhasil dihapus");
        return ResponseEntity.ok(response);
    }
}
