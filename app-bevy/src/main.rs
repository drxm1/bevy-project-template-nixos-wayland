#![allow(dead_code)]
use bevy::prelude::*;

use lib_utils::UtilsPlugin;

/* COMPONENTS:
 * Rust structs that implement the 'Component' trait */

#[derive(Component)]
struct Position {
    x: f32,
    y: f32,
}

#[derive(Component)]
struct Person;

#[derive(Component)]
struct Name(String);

/* SYSTEMS:
 * Normal rust functions */

// EXAMPLE SYSTEMS
fn print_position_system(query: Query<&Position>) {
    for position in &query {
        println!("position: {} {}", position.x, position.y);
    }
}
fn hello_world() {
    println!("hello world!");
}

// STARTUP SYSTEMS
fn add_people(mut commands: Commands) {
    commands.spawn((Person, Name("Elaina Proctor".to_string())));
    commands.spawn((Person, Name("Renzo Hume".to_string())));
    commands.spawn((Person, Name("Zayna Nieves".to_string())));
}

// OTHER SYSTEMS
fn greet_people(time: Res<Time>, mut timer: ResMut<GreetTimer>, query: Query<&Name, With<Person>>) {
    if timer.0.tick(time.delta()).just_finished() {
        for name in &query {
            println!("hello {}!", name.0)
        }
    }
}
fn update_people(mut query: Query<&mut Name, With<Person>>) {
    for mut name in &mut query {
        if name.0 == "Elaina Proctor" {
            name.0 = "Elaina Hume".to_string();
            break;
        }
    }
}

/* RESOURCES:
 * */
#[derive(Resource)]
struct GreetTimer(Timer);

/* ENTITIES:
 * a simple type containing a unique integer */
struct Entity(u64);

/* PLUGINS
 * */
pub struct HelloPlugin;
impl Plugin for HelloPlugin {
    fn build(&self, app: &mut App) {
        app.insert_resource(GreetTimer(Timer::from_seconds(2.0, TimerMode::Repeating)))
            .add_systems(Startup, add_people)
            .add_systems(Update, (update_people, greet_people).chain());
    }
}

fn main() {
    App::new()
        .add_plugins((DefaultPlugins, HelloPlugin))
        .add_plugins(UtilsPlugin)
        // .add_systems(Startup, (
        //     )
        // )
        // .add_systems(Update, (
        //     )
        // )
        .run();
}
