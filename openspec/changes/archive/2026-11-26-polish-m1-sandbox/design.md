# Design

## Decisions

### Catmull-Rom history
Bilinear history reads act as a small blur on every frame whose reprojection falls between pixels, that is every frame
the camera moves; repeated each frame, it softens the image quickly. A Catmull-Rom filter (five bilinear reads,
dropping the four corner taps) keeps detail. The result is still clamped to the current neighbourhood.

### Motion-weighted blend
The current frame's weight rises from 10% to 25% as the reprojection moves up to four pixels, so fast motion keeps
less history (less smear) and a still picture accumulates the most anti-aliasing.

### Contrast-adaptive sharpening for display only
TAA averages frames jittered across a pixel, about a pixel of blur. The post pass sharpens the tone-mapped image
(0..1, where CAS's weights are defined) from the pixel and its four neighbours, less where contrast is already high,
so edges do not ring. The history itself stays unsharpened, so sharpening never accumulates. It runs only with TAA.

### Measured
On the sandbox at the High level, the mean absolute Laplacian (a sharpness measure) of TAA frames rose from 15.4 to
18.6, against 19.5 without anti-aliasing; edges stay smooth.
