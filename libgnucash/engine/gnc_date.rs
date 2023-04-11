use std::os::raw::c_int;
use std::mem;

type time_t = i64;

#[repr(C)]
pub struct tm {
    pub tm_sec: c_int,
    pub tm_min: c_int,
    pub tm_hour: c_int,
    pub tm_mday: c_int,
    pub tm_mon: c_int,
    pub tm_year: c_int,
    pub tm_wday: c_int,
    pub tm_yday: c_int,
    pub tm_isdst: c_int,
}

#[no_mangle]
pub extern "C" fn gnc_localtime_r(secs: *const time_t, time: *mut tm) -> *mut tm {
    unsafe {
        let t = mem::transmute::<*mut tm, *mut libc::tm>(time);
        libc::localtime_r(secs, t);
        mem::transmute::<*mut libc::tm, *mut tm>(t)
    }
}
