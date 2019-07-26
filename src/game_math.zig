usingnamespace @import("std").math;
usingnamespace @import("./math3d.zig");

pub fn clamp(val: f32, min_val: f32, max_val: f32) f32 {
    return min(max_val, max(min_val, val));
}

pub fn saturate(f: f32) f32 {
    if (f < 0) return 0;
    if (f > 1) return 1;
    return f;
}

pub fn unlerp(ax: f32, a1: f32, a2: f32) f32 {
    return (ax - a1) / (a2 - a1);
}

pub fn smooth_damp_vec3(current: Vec3, target: Vec3, current_velocity: *Vec3, smooth_time: f32, delta_time: f32) Vec3 {
    const x: f32 = smooth_damp(current.x, target.x, &current_velocity.x, smooth_time, delta_time);
    const y: f32 = smooth_damp(current.y, target.y, &current_velocity.y, smooth_time, delta_time);
    const z: f32 = smooth_damp(current.z, target.z, &current_velocity.z, smooth_time, delta_time);

    return vec3(x, y, z);
}

// thanks Unity decompiled
pub fn smooth_damp(
    current: f32,
    _target: f32,
    current_velocity: *f32,
    _smooth_time: f32,
    delta_time: f32,
    //max_speed: f32 = inf(f32),
) f32 {
    var target = _target;
    const max_speed = inf(f32);

    const smooth_time = max(0.0001, _smooth_time);

    var num: f32 = 2.0 / smooth_time;
    var num2: f32 = num * delta_time;
    var num3: f32 = 1.0 / (1.0 + num2 + 0.48 * num2 * num2 + 0.235 * num2 * num2 * num2);
    var num4: f32 = current - target;
    var num5: f32 = target;
    var num6: f32 = max_speed * smooth_time;
    num4 = clamp(num4, -num6, num6);
    target = current - num4;
    var num7: f32 = (current_velocity.* + num * num4) * delta_time;
    current_velocity.* = (current_velocity.* - num * num7) * num3;
    var num8: f32 = target + (num4 + num7) * num3;

    if ((num5 - current > 0.0) == (num8 > num5)) {
        num8 = num5;
        current_velocity.* = (num8 - num5) / delta_time;
    }

    return num8;
}
