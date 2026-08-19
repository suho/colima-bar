import Foundation
import Testing

@testable import ColimaBar

struct DockerInspectTests {
  @Test
  func convertsInspectJSONToContainer() throws {
    let json = """
      [{
        "Id": "abcdef1234567890",
        "Name": "/web",
        "Config": {
          "Image": "example/web:latest",
          "Labels": {
            "com.docker.compose.project": "example",
            "com.docker.compose.service": "web"
          }
        },
        "State": {"Status": "running", "Health": {"Status": "healthy"}},
        "Mounts": [{"Type": "bind", "Source": "/tmp/project", "Destination": "/app"}],
        "NetworkSettings": {
          "Ports": {
            "4000/tcp": [
              {"HostIp": "0.0.0.0", "HostPort": "4000"},
              {"HostIp": "::", "HostPort": "4000"}
            ]
          }
        }
      }]
      """

    let inspect = try #require(
      JSONDecoder().decode([DockerInspect].self, from: Data(json.utf8)).first)
    let container = inspect.container()

    #expect(container.name == "web")
    #expect(container.shortID == "abcdef123456")
    #expect(container.isRunning)
    #expect(container.composeProject == "example")
    #expect(container.ports.count == 1)
    #expect(container.ports.first?.address == "localhost:4000")
    #expect(container.mounts.first?.destination == "/app")
  }

  @Test
  func keepsStoppedContainerWithoutPorts() throws {
    let json = """
      [{
        "Id": "123456789012",
        "Name": "/worker",
        "Config": {"Image": "worker:dev", "Labels": null},
        "State": {"Status": "exited"},
        "Mounts": [],
        "NetworkSettings": {"Ports": {"9000/tcp": null}}
      }]
      """

    let inspect = try #require(
      JSONDecoder().decode([DockerInspect].self, from: Data(json.utf8)).first)
    let container = inspect.container()

    #expect(!container.isRunning)
    #expect(container.ports.isEmpty)
    #expect(container.labels.isEmpty)
  }
}
