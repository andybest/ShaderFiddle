ShaderFiddle
============

ShaderFiddle is an OS X application that allows for live experimentation with GLSL Fragment shaders. It is designed to be (mostly) compatible with [shadertoy](http://shadertoy.com).

All of the uniforms are added automatically to the top of the fragment shader, leaving just the main method to be created.

There are several uniforms available for use:

	uniform float iGlobalTime	// Time in seconds
	uniform vec2 iResolution	// Viewport resolution
	uniform vec4 iDate			// {year, month, day, time in seconds}
	uniform sampler2D iFFT		// FFT data (256x1 texture, data is in the red channel)

The fragment colour is output with the variable

	out vec4 fragColor

Shaders are `#version 330`, so GL_FragColor is not available for use.

The FFT information is taken from the current system audio input source.