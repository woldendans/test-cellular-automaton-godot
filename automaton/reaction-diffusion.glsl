#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0, std140) uniform Parameters {
    vec4 p; // p.x -> width, p.y -> height, p.z -> diffusion factor
}
parameters;

// Input buffer
layout(set = 0, binding = 1, std430) restrict readonly buffer Previous {
    vec2 data[];
}
previous;

// Output buffer
layout(set = 0, binding = 2, std430) restrict writeonly buffer Next {
    vec2 data[];
}
next;

layout(set = 0, binding = 3, r8) restrict writeonly uniform image2D outputImage;

#define F 0.005
#define D 0.049

// The code we want to execute in each invocation
void main() {
    uint width = uint(parameters.p.x);
    uint height = uint(parameters.p.y);
    uint minX = gl_GlobalInvocationID.x > 0 ? gl_GlobalInvocationID.x - 1 : 0;
    uint minY = gl_GlobalInvocationID.y > 0 ? gl_GlobalInvocationID.y - 1 : 0;
    uint maxX = min(width - 1, gl_GlobalInvocationID.x + 1);
    uint maxY = min(height - 1, gl_GlobalInvocationID.y + 1);
    uint idx = gl_GlobalInvocationID.x * height + gl_GlobalInvocationID.y;
    
    vec2 cell = previous.data[idx];
    float u = cell.x;
    float v = cell.y;
    float r = u * u * v;

    float un = 0.;
    float vn = 0.;
    float count = 0.;
    for(uint x = minX; x <= maxX; ++x)
    {
        for(uint y = minY; y <= maxY; ++y)
        {
            if (x != gl_GlobalInvocationID.x || y != gl_GlobalInvocationID.y) {
                vec2 p = previous.data[x * height + y];
                un += p.x;
                vn += p.y;
                count += 1.0;
            }
        }
    }
    float du = (un / float(count)) - u;
    float dv = (vn / float(count)) - v;

    float lf = F + (float(gl_GlobalInvocationID.x) / float(width)) * 0.06;
    float ld = D + (float(gl_GlobalInvocationID.y) / float(height)) * 0.02;

    vec2 res = vec2(
        u + (parameters.p.z * du + r - (lf + ld) * u),
        v + (dv - r + lf * (1.0 - v))
    );

    next.data[idx] = res;

	float l = (res.x - res.y + 1.0) / 2.0;
    imageStore(outputImage, ivec2(gl_GlobalInvocationID.xy), vec4(l, 0.0, 0.0, 0.0));
}
