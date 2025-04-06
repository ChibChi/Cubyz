#version 430

layout (location=0)  in vec2 inTexCoords;

out vec2 texCoords;

uniform mat4 projection;
uniform mat4 view;
uniform mat4 view;
uniform vec3 position;
// uniform vec4 color;

vec3 billboard(float scale) {
    CameraRight_worldspace = {ViewMatrix[0][0], ViewMatrix[1][0], ViewMatrix[2][0]}
    CameraUp_worldspace = {ViewMatrix[0][1], ViewMatrix[1][1], ViewMatrix[2][1]}

    return position
    + CameraRight_worldspace * squareVertices.x * scale
    + CameraUp_worldspace * squareVertices.y * scale;
}

void main()
{
    float scale = 10.0f;
    texCoords = inTexCoords;
    gl_Position = projection * vec4((inTexCoords * scale), 0.0, 1.0);
}