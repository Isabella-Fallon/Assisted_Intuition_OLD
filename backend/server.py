import asyncio
import websockets
import math
import random
import sys

# Set the event loop policy for Windows (necessary for async on Windows)
if sys.platform.startswith('win'):
    asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())

# Initialize the time variable for the sine wave
time_var = 0.0

# Function to generate and send sine wave coordinates with a delay
async def data_stream(websocket):
    global time_var
    print("Client connected")
    try:
        while True:
            # Calculate new x, y, and z using sine wave formulas with different frequencies and added randomness
            x = 0.5 * (1 + math.sin(time_var + random.uniform(-0.5, 0.5)))  # X-coordinate with added randomness
            y = 0.5 * (1 + math.sin(2 * time_var + random.uniform(-0.5, 0.5)))  # Y-coordinate with added randomness
            z = 0.5 * (1 + math.sin(3 * time_var + random.uniform(-0.5, 0.5)))  # Z-coordinate with added randomness

            # Send the generated coordinates to the client
            await websocket.send(f"{x},{y},{z}")

            # Increase the time variable to make the sine wave progress
            time_var += 0.1

            # Delay to slow down the data transmission
            await asyncio.sleep(0.1)  # Shorter delay for smoother transitions
    except websockets.ConnectionClosed:
        print("Client disconnected")

# Start the WebSocket server
async def start_server():
    server = await websockets.serve(data_stream, "127.0.0.1", 8000)
    print("Server started on ws://127.0.0.1:8000")
    await server.wait_closed()

# Run the server
if __name__ == "__main__":
    # Create and run the event loop
    asyncio.run(start_server())