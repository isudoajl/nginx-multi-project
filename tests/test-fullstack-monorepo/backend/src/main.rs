use warp::Filter;
use serde_json::json;
use std::env;

#[tokio::main]
async fn main() {
    println!("Starting test backend server...");
    
    // Get port from environment variable, default to 8080
    let port: u16 = env::var("PORT")
        .unwrap_or_else(|_| "8080".to_string())
        .parse()
        .expect("PORT must be a valid number");
    
    println!("Server will listen on port: {}", port);

    // Health check endpoint
    let health = warp::path("health")
        .and(warp::get())
        .map(|| {
            println!("Health check requested");
            "OK"
        });

    // Status endpoint
    let status = warp::path("status")
        .and(warp::get())
        .map(|| {
            println!("Status endpoint requested");
            warp::reply::json(&json!({
                "status": "running",
                "service": "test-backend",
                "timestamp": chrono::Utc::now().to_rfc3339(),
                "message": "Backend is working correctly"
            }))
        });

    // API root endpoint
    let api_root = warp::path::end()
        .and(warp::get())
        .map(|| {
            println!("API root requested");
            warp::reply::json(&json!({
                "message": "Test Backend API",
                "version": "0.1.0",
                "endpoints": ["/health", "/status"]
            }))
        });

    // Combine all routes
    let routes = health
        .or(status)
        .or(api_root)
        .with(warp::cors().allow_any_origin());

    println!("Test backend server starting on 0.0.0.0:{}", port);
    
    warp::serve(routes)
        .run(([0, 0, 0, 0], port))
        .await;
}
