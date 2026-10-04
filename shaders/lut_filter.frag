#version 460 core

#include <flutter/runtime_effect.glsl>

uniform sampler2D uSource;

out vec4 fragColor;

void main() {
  fragColor = texture(uSource, FlutterFragCoord().xy);
}
