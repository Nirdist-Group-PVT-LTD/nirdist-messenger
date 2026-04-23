package com.nirdist.util;

public final class PhoneNumberNormalizer {

    private PhoneNumberNormalizer() {
    }

    public static String normalize(String value) {
        if (value == null) {
            return null;
        }

        String trimmed = value.trim();
        if (trimmed.isEmpty()) {
            return null;
        }

        StringBuilder digits = new StringBuilder();
        for (int index = 0; index < trimmed.length(); index++) {
            char current = trimmed.charAt(index);
            if (Character.isDigit(current)) {
                digits.append(current);
            }
        }

        if (digits.length() == 0) {
            return null;
        }

        return "+" + digits;
    }
}