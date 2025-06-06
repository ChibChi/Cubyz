#version 460

layout(location = 0) out vec4 fragColor;

layout(location = 0) in vec2 texCoords;
layout(location = 1) in vec2 normalizedTexCoords;
layout(location = 2) in vec3 direction;

layout(binding = 3) uniform sampler2D color;
layout(binding = 4) uniform sampler2D depthTexture;

layout(location = 1) uniform vec2 tanXY;
layout(location = 2) uniform float zNear;
layout(location = 3) uniform float zFar;

layout(location = 4) uniform ivec3 playerPositionInteger;
layout(location = 5) uniform vec3 playerPositionFraction;

struct Fog {
	vec3 color;
	float density;
	float fogLower;
	float fogHigher;
};

layout(location = 6) uniform Fog fog;

float zFromDepth(float depthBufferValue) {
	return zNear*zFar/(depthBufferValue*(zNear - zFar) + zFar);
}

float densityIntegral(float dist, float zStart, float zDist, float fogLower, float fogHigher) {
	// The density is constant until fogLower, then gets smaller linearly until reaching fogHigher, past which there is no fog.
	if(zDist < 0) {
		zStart += zDist;
		zDist = -zDist;
	}
	if(abs(zDist) < 0.001) {
		zDist = 0.001;
	}
	float beginLower = min(fogLower, zStart);
	float endLower = min(fogLower, zStart + zDist);
	float beginMid = max(fogLower, min(fogHigher, zStart));
	float endMid = max(fogLower, min(fogHigher, zStart + zDist));
	float midIntegral = -0.5*(endMid - fogHigher)*(endMid - fogHigher)/(fogHigher - fogLower) - -0.5*(beginMid - fogHigher)*(beginMid - fogHigher)/(fogHigher - fogLower);
	if(fogHigher == fogLower) midIntegral = 0;

	return (endLower - beginLower + midIntegral)/zDist*dist;
}

float calculateFogDistance(float dist, float densityAdjustment, float zStart, float zScale, float fogDensity, float fogLower, float fogHigher) {
	float distCameraTerrain = densityIntegral(dist*densityAdjustment, zStart, zScale*dist*densityAdjustment, fogLower, fogHigher)*fogDensity;
	float distFromCamera = 0;
	float distFromTerrain = distFromCamera - distCameraTerrain;
	if(distCameraTerrain < 10) { // Resolution range is sufficient.
		return distFromTerrain;
	} else {
		// Here we have a few options to deal with this. We could for example weaken the fog effect to fit the entire range.
		// I decided to keep the fog strength close to the camera and far away, with a fog-free region in between.
		// I decided to this because I want far away fog to work (e.g. a distant ocean) as well as close fog(e.g. the top surface of the water when the player is under it)
		if(distFromTerrain > -5 && dist != 0) {
			return distFromTerrain;
		} else if(distFromCamera < 5) {
			return distFromCamera - 10;
		} else {
			return -5;
		}
	}
}

vec3 applyFrontfaceFog(float fogDistance, vec3 fogColor, vec3 inColor) {
	float fogFactor = exp(fogDistance);
	inColor *= fogFactor;
	inColor += fogColor;
	inColor -= fogColor*fogFactor;
	return inColor;
}

vec3 fetch(ivec2 pos) {
	vec4 rgba = texelFetch(color, pos, 0);
	float densityAdjustment = sqrt(dot(tanXY*(normalizedTexCoords*2 - 1), tanXY*(normalizedTexCoords*2 - 1)) + 1);
	float dist = zFromDepth(texelFetch(depthTexture, pos, 0).r);
	float fogDistance = calculateFogDistance(dist, densityAdjustment, playerPositionFraction.z, normalize(direction).z, fog.density, fog.fogLower - playerPositionInteger.z, fog.fogHigher - playerPositionInteger.z);
	vec3 fogColor = fog.color;
	rgba.rgb = applyFrontfaceFog(fogDistance, fog.color, rgba.rgb);
	return rgba.rgb/rgba.a;
}

vec3 linearSample(ivec2 start) {
	vec3 outColor = vec3(0);
	outColor += fetch(start);
	outColor += fetch(start + ivec2(0, 2));
	outColor += fetch(start + ivec2(2, 0));
	outColor += fetch(start + ivec2(2, 2));
	return outColor*0.25;
}

void main() {
	vec3 bufferData = linearSample(ivec2(texCoords));
	float bloomFactor = max(max(bufferData.x, max(bufferData.y, bufferData.z)) - 1.0, 0);
	fragColor = vec4(bufferData*bloomFactor, 1);
}
