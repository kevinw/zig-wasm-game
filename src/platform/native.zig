pub usingnamespace @cImport({
    @cDefine("_CRT_SECURE_NO_WARNINGS", "");

    @cInclude("glad/glad.h");
    @cInclude("GLFW/glfw3.h");
    @cInclude("png.h");
    @cInclude("math.h");
    @cInclude("stdlib.h");
    @cInclude("stdio.h");

    // nuklear
    //@cInclude("nuklear_config.h");
    //@cInclude("nuklear.h");
    //@cInclude("demo/glfw_opengl3/nuklear_glfw_gl3.h");
});
