pub fn saturate(f: f32) f32 {
    if (f < 0) return 0;
    if (f > 1) return 1;
    return f;
}

pub fn unlerp(ax: f32, a1: f32, a2: f32) f32 {
    return (ax - a1) / (a2 - a1);
}
