pub fn kitty_image_escape(base64_png: &str) -> String {
    format!("\x1b_Ga=T,f=100,m=0;{base64_png}\x1b\\")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn kitty_image_escape_wraps_base64_png_payload() {
        let escape = kitty_image_escape("iVBORw0KGgo=");

        assert!(escape.starts_with("\x1b_G"));
        assert!(escape.contains("a=T"));
        assert!(escape.contains("f=100"));
        assert!(escape.contains(";iVBORw0KGgo="));
        assert!(escape.ends_with("\x1b\\"));
    }
}
