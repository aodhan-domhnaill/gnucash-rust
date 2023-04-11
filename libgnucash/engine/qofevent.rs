use std::os::raw::c_int;

pub type QofEventId = c_int;

const QOF_EVENT_BASE: c_int = 8;

const fn QOF_MAKE_EVENT(x: c_int) -> c_int {
    1 << (x)
}

pub const QOF_EVENT_NONE: QofEventId = 0;
pub const QOF_EVENT_CREATE: QofEventId = QOF_MAKE_EVENT(0);
pub const QOF_EVENT_MODIFY: QofEventId = QOF_MAKE_EVENT(1);
pub const QOF_EVENT_DESTROY: QofEventId = QOF_MAKE_EVENT(2);
pub const QOF_EVENT_ADD: QofEventId = QOF_MAKE_EVENT(3);
pub const QOF_EVENT_REMOVE: QofEventId = QOF_MAKE_EVENT(4);
pub const QOF_EVENT__LAST: QofEventId = QOF_MAKE_EVENT(QOF_EVENT_BASE - 1);
pub const QOF_EVENT_ALL: QofEventId = (0xff);
