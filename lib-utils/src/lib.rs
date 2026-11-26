use bevy::prelude::*;

pub fn print_hello_world() {
    info!("Hello from utils crate!");
}

pub struct UtilsPlugin;

impl Plugin for UtilsPlugin {
    fn build(&self, app: &mut App) {
        app.add_systems(Startup, print_hello_world);
    }
}
