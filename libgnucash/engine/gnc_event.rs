use engine::qofevent;

#[no_mangle]
pub extern "C" fn qofeventid_to_string(id: qofevent::QofEventId) -> &'static str {
    match id {
        0 => "NONE",
        qofevent::QOF_EVENT_CREATE => "CREATE",
        qofevent::QOF_EVENT_MODIFY => "MODIFY",
        qofevent::QOF_EVENT_DESTROY => "DESTROY",
        qofevent::QOF_EVENT_ADD => "ADD",
        qofevent::QOF_EVENT_REMOVE => "REMOVE",
        GNC_EVENT_ITEM_ADDED => "ITEM_ADDED",
        GNC_EVENT_ITEM_REMOVED => "ITEM_REMOVED",
        GNC_EVENT_ITEM_CHANGED => "ITEM_CHANGED",
        _ => "<unknown, maybe multiple>",
    }
}
