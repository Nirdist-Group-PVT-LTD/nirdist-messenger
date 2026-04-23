package com.nirdist.controller;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.nirdist.dto.AuthResponse;
import com.nirdist.dto.FirebaseAuthExchangeRequest;
import com.nirdist.dto.PhoneAuthExchangeRequest;
import com.nirdist.service.AuthService;

import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/auth")
@CrossOrigin(origins = "*")
public class AuthController {

    private final AuthService authService;

    public AuthController(AuthService authService) {
        this.authService = authService;
    }

    @PostMapping("/firebase/exchange")
    public ResponseEntity<AuthResponse> exchangeFirebaseToken(@Valid @RequestBody FirebaseAuthExchangeRequest request) {
        AuthResponse response = authService.exchangeFirebaseToken(request);
        HttpStatus status = response.created() ? HttpStatus.CREATED : HttpStatus.OK;
        return ResponseEntity.status(status).body(response);
    }

    @PostMapping("/phone/exchange")
    public ResponseEntity<AuthResponse> exchangePhoneNumber(@Valid @RequestBody PhoneAuthExchangeRequest request) {
        AuthResponse response = authService.exchangePhoneNumber(request);
        HttpStatus status = response.created() ? HttpStatus.CREATED : HttpStatus.OK;
        return ResponseEntity.status(status).body(response);
    }
}