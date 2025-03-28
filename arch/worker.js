export default {
  async fetch(request, env) {
    try {
      const response = await fetch(
        "https://raw.githubusercontent.com/VictorBravo9er/scripts/refs/heads/main/arch.install.sh"
      );

      if (!response.ok) {
        return new Response(`Failed to fetch file: ${response.statusText}`, {
          status: response.status,
        });
      }

      // Clone the response to modify the headers
      const modifiedResponse = new Response(response.body, response);

      // Set the desired headers
      modifiedResponse.headers.set("Content-Type", "text/plain");
      modifiedResponse.headers.set(
        "Content-Disposition",
        'attachment; filename="install.sh"'
      );

      return modifiedResponse;
    } catch (error) {
      console.error("Error in worker:", error);
      return new Response("Internal Server Error", { status: 500 });
    }
  },
};
