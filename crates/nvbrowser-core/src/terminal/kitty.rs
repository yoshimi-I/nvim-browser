#[derive(Debug, Clone, PartialEq, Eq)]
pub struct KittyImageTransfer {
    image_id: u32,
    width_px: u32,
    height_px: u32,
    base64_png: String,
}

impl KittyImageTransfer {
    pub fn new(
        image_id: u32,
        width_px: u32,
        height_px: u32,
        base64_png: impl Into<String>,
    ) -> Self {
        Self {
            image_id,
            width_px,
            height_px,
            base64_png: base64_png.into(),
        }
    }

    pub fn escape(&self) -> String {
        format!(
            "\x1b_Ga=T,i={},f=100,s={},v={},m=0;{}\x1b\\",
            self.image_id, self.width_px, self.height_px, self.base64_png
        )
    }

    pub fn upload_escape(&self) -> String {
        format!(
            "\x1b_Ga=t,i={},f=100,s={},v={},m=0;{}\x1b\\",
            self.image_id, self.width_px, self.height_px, self.base64_png
        )
    }

    pub fn placed_escape(&self, placement_id: u32, columns: u32, rows: u32) -> String {
        format!(
            "\x1b_Ga=T,i={},p={},c={},r={},f=100,s={},v={},m=0;{}\x1b\\",
            self.image_id,
            placement_id,
            columns.max(1),
            rows.max(1),
            self.width_px,
            self.height_px,
            self.base64_png
        )
    }

    pub fn virtual_placement_escape(&self, columns: u32, rows: u32) -> String {
        let control = format!(
            "a=T,q=2,U=1,i={},c={},r={},f=100,s={},v={}",
            self.image_id,
            columns.max(1),
            rows.max(1),
            self.width_px,
            self.height_px
        );

        chunked_escape(&control, &self.base64_png)
    }
}

fn chunked_escape(control: &str, payload: &str) -> String {
    const CHUNK_SIZE: usize = 4096;
    if payload.len() <= CHUNK_SIZE {
        return format!("\x1b_G{control},m=0;{payload}\x1b\\");
    }

    let mut escape = String::new();
    let mut offset = 0;
    while offset < payload.len() {
        let end = (offset + CHUNK_SIZE).min(payload.len());
        let chunk = &payload[offset..end];
        let more = if end < payload.len() { 1 } else { 0 };
        if offset == 0 {
            escape.push_str(&format!("\x1b_G{control},m={more};{chunk}\x1b\\"));
        } else {
            escape.push_str(&format!("\x1b_Gm={more};{chunk}\x1b\\"));
        }
        offset = end;
    }

    escape
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct KittyImagePlacement {
    image_id: u32,
    placement_id: u32,
    columns: u32,
    rows: u32,
}

impl KittyImagePlacement {
    pub const fn new(image_id: u32, placement_id: u32, columns: u32, rows: u32) -> Self {
        Self {
            image_id,
            placement_id,
            columns,
            rows,
        }
    }

    pub fn escape(&self) -> String {
        format!(
            "\x1b_Ga=p,i={},p={},c={},r={}\x1b\\",
            self.image_id, self.placement_id, self.columns, self.rows
        )
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct KittyImageDelete {
    image_id: u32,
}

impl KittyImageDelete {
    pub const fn new(image_id: u32) -> Self {
        Self { image_id }
    }

    pub fn escape(&self) -> String {
        format!("\x1b_Ga=d,d=i,i={}\x1b\\", self.image_id)
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct KittyPlacementDelete {
    image_id: u32,
    placement_id: u32,
}

impl KittyPlacementDelete {
    pub const fn new(image_id: u32, placement_id: u32) -> Self {
        Self {
            image_id,
            placement_id,
        }
    }

    pub fn escape(&self) -> String {
        format!(
            "\x1b_Ga=d,d=p,i={},p={}\x1b\\",
            self.image_id, self.placement_id
        )
    }
}

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

    #[test]
    fn image_transfer_supports_stable_ids_and_dimensions() {
        let transfer = KittyImageTransfer::new(42, 800, 600, "iVBORw0KGgo=");

        assert_eq!(
            transfer.escape(),
            "\x1b_Ga=T,i=42,f=100,s=800,v=600,m=0;iVBORw0KGgo=\x1b\\"
        );
    }

    #[test]
    fn image_transfer_can_upload_without_displaying() {
        let transfer = KittyImageTransfer::new(42, 800, 600, "iVBORw0KGgo=");

        assert_eq!(
            transfer.upload_escape(),
            "\x1b_Ga=t,i=42,f=100,s=800,v=600,m=0;iVBORw0KGgo=\x1b\\"
        );
    }

    #[test]
    fn image_transfer_can_display_with_cell_placement() {
        let transfer = KittyImageTransfer::new(42, 800, 600, "iVBORw0KGgo=");

        assert_eq!(
            transfer.placed_escape(7, 80, 24),
            "\x1b_Ga=T,i=42,p=7,c=80,r=24,f=100,s=800,v=600,m=0;iVBORw0KGgo=\x1b\\"
        );
    }

    #[test]
    fn image_transfer_can_create_virtual_unicode_placement() {
        let transfer = KittyImageTransfer::new(42, 800, 600, "iVBORw0KGgo=");

        assert_eq!(
            transfer.virtual_placement_escape(80, 24),
            "\x1b_Ga=T,q=2,U=1,i=42,c=80,r=24,f=100,s=800,v=600,m=0;iVBORw0KGgo=\x1b\\"
        );
    }

    #[test]
    fn image_transfer_chunks_large_virtual_unicode_payloads() {
        let transfer = KittyImageTransfer::new(42, 800, 600, "a".repeat(4097));

        let escape = transfer.virtual_placement_escape(80, 24);

        assert!(escape.starts_with("\x1b_Ga=T,q=2,U=1,i=42,c=80,r=24,f=100,s=800,v=600,m=1;"));
        assert!(escape.contains(&format!("{}{}", "a".repeat(4096), "\x1b\\\x1b_Gm=0;a")));
    }

    #[test]
    fn image_placement_addresses_existing_image() {
        let placement = KittyImagePlacement::new(42, 7, 80, 24);

        assert_eq!(placement.escape(), "\x1b_Ga=p,i=42,p=7,c=80,r=24\x1b\\");
    }

    #[test]
    fn image_delete_clears_existing_image() {
        let delete = KittyImageDelete::new(42);

        assert_eq!(delete.escape(), "\x1b_Ga=d,d=i,i=42\x1b\\");
    }

    #[test]
    fn placement_delete_clears_specific_placement() {
        let delete = KittyPlacementDelete::new(42, 7);

        assert_eq!(delete.escape(), "\x1b_Ga=d,d=p,i=42,p=7\x1b\\");
    }
}
