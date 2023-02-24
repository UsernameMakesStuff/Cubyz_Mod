const std = @import("std");
const Allocator = std.mem.Allocator;

const main = @import("root");
const graphics = main.graphics;
const draw = graphics.draw;
const Image = graphics.Image;
const Shader = graphics.Shader;
const TextBuffer = graphics.TextBuffer;
const Texture = graphics.Texture;
const random = main.random;
const vec = main.vec;
const Vec2f = vec.Vec2f;

const gui = @import("../gui.zig");
const GuiComponent = gui.GuiComponent;

const Button = @This();

const border: f32 = 3;
const fontSize: f32 = 16;

var texture: Texture = undefined;
pub var shader: Shader = undefined;
var buttonUniforms: struct {
	screen: c_int,
	start: c_int,
	size: c_int,
	color: c_int,
	scale: c_int,

	image: c_int,
	pressed: c_int,
	randomOffset: c_int,
} = undefined;

pressed: bool = false,
onAction: *const fn() void,
text: TextBuffer,
textSize: Vec2f = undefined,
randomOffset: Vec2f = undefined,

pub fn __init() !void {
	shader = try Shader.create("assets/cubyz/shaders/ui/button.vs", "assets/cubyz/shaders/ui/button.fs");
	buttonUniforms = shader.bulkGetUniformLocation(@TypeOf(buttonUniforms));
	shader.bind();
	graphics.c.glUniform1i(buttonUniforms.image, 0);
	texture = Texture.init();
	const image = try Image.readFromFile(main.threadAllocator, "assets/cubyz/ui/button.png");
	defer image.deinit(main.threadAllocator);
	try texture.generate(image);
}

pub fn __deinit() void {
	shader.delete();
	texture.deinit();
}

pub fn init(pos: Vec2f, width: f32, allocator: Allocator, text: []const u8, onAction: *const fn() void) Allocator.Error!GuiComponent {
	var self = Button {
		.onAction = onAction,
		.text = try TextBuffer.init(allocator, text, .{}, false),
		.randomOffset = Vec2f{
			random.nextFloat(&main.seed),
			random.nextFloat(&main.seed),
		},
	};
	self.textSize = try self.text.calculateLineBreaks(fontSize, width - 3*border);
	return GuiComponent {
		.pos = pos,
		.size = .{@max(width, self.textSize[0] + 3*border), self.textSize[1] + 3*border},
		.impl = .{.button = self}
	};
}

pub fn deinit(self: Button) void {
	self.text.deinit();
}

pub fn mainButtonPressed(self: *Button, _: *const GuiComponent, _: Vec2f) void {
	self.pressed = true;
}

pub fn mainButtonReleased(self: *Button, component: *const GuiComponent, mousePosition: Vec2f) void {
	if(self.pressed) {
		self.pressed = false;
		if(component.contains(mousePosition)) {
			self.onAction();
		}
	}
}

pub fn render(self: *Button, component: *const GuiComponent, mousePosition: Vec2f) !void {
	graphics.c.glActiveTexture(graphics.c.GL_TEXTURE0);
	texture.bind();
	shader.bind();
	graphics.c.glUniform2f(buttonUniforms.randomOffset, self.randomOffset[0], self.randomOffset[1]);
	graphics.c.glUniform1i(buttonUniforms.pressed, 0);
	if(self.pressed) {
		draw.setColor(0xff000000);
		graphics.c.glUniform1i(buttonUniforms.pressed, 1);
	} else if(component.contains(mousePosition)) {
		draw.setColor(0xff000040);
	} else {
		draw.setColor(0xff000000);
	}
	draw.customShadedRect(buttonUniforms, component.pos, component.size);
	const textPos = component.pos + component.size/@splat(2, @as(f32, 2.0)) - self.textSize/@splat(2, @as(f32, 2.0));
	try self.text.render(textPos[0], textPos[1], fontSize);
}