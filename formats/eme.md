# EME Files

## Stores

- Email messages

## Format

```zig
struct {
    box_count: u8;
    box_names: struct {
        name_len: u8;
        name: u8[name_len];
    }[box_count];
    
    email_count: u16;
    email_data: struct {
        to_len: u8;
        to: u8[to_len];
        from_len: u8;
        from: u8[from_len];
        conts_len: u16;
        conts: u8[conts_len];
        
        box: u8;
        
        cond_id: u8;
        cond_data_len: u8; 
        cond_data: u8[cond_data_len];
    }[email_count];
};
```
