const steam = @import("steam.zig");

pub const CreateItem = extern struct {
    pub const ID: steam.CallbackId = .CreateItem;

    result: steam.Result,
    file_id: steam.PublishedFileId,
    needs_workshop_agree: bool,

    //    04190927 :1441796 > IClientUtils::GetAPICallResult( 0xF0B1C18BA0C46DA5, 24, 3403, ) = 1, 24 bytes [01 00 00 00 4d 85 3f d0 00 00 00 00 00 74 65 6d 00 00 00 00 00 00 00 00], 0,

};

pub const UpdateItem = extern struct {
    pub const ID: steam.CallbackId = .UpdateItem;

    result: steam.Result,
    needs_workshop_agree: bool,
};
