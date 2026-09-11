const steam = @import("root.zig");

pub const CreateItem = packed struct {
    pub const ID: steam.CallbackId = .create_item;

    result: steam.Result,
    file_id: steam.UGC.PublishedFile,
    needs_workshop_agree: bool,

    //    04190927 :1441796 > IClientUtils::GetAPICallResult( 0xF0B1C18BA0C46DA5, 24, 3403, ) = 1, 24 bytes [01 00 00 00 4d 85 3f d0 00 00 00 00 00 74 65 6d 00 00 00 00 00 00 00 00], 0,
};

pub const UpdateItem = packed struct {
    pub const ID: steam.CallbackId = .update_item;

    result: steam.Result,
    needs_workshop_agree: bool,
};

pub const UGCQueryCompleted = packed struct {
    pub const ID: steam.CallbackId = .ugc_query_completed;

    handle: u64,
    result: steam.Result,
    num_results: u32,
    total_results: u32,
    cached: bool,
};
