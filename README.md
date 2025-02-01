# Test: Reaction-Diffusion Cellular Automaton

This project is a simple Godot implementation of a Reaction-Diffusion cellular automaton using compute shaders.

## The render node parameters

* `Shader File` should be set at the shader's `.glsl` file. It exists to ease testing other automaton using the same interface. The `.glsl` file must be edited in an external editor as of Godot 4.4-beta2.
* `Size` is the width and height in pixels. The project default window is 1024x768.
* `GPS` is the desired iteration per seconds on the GPU (generations per seconds). Note that if the GPU can't keep up, the actual number of iterations per seonds might be lower.
* `FPS` is the desired number of readback of the texture to display it. If `Write Frames` is used, it is also the theorical FPS of the resulting collection of frames.
* `Write Frames` will write frames in the Godot's user data folder, in a `frames` older in the project's folder (see [Godot's documentation](https://docs.godotengine.org/en/latest/tutorials/io/data_paths.html#accessing-persistent-user-data-user)). This will be done at the end of the animation so `Stop at Gen` must be used. Beware of the memory usage.
* `Stop at Gen` specifies at what generation to stop the animation and write the frames. It is in generations, so at 300 GPS for a 70s animation you need to set it to `300 * 70 = 21000`.
