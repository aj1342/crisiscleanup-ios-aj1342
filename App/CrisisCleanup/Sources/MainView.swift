import SwiftUI

struct NavTabView: View {
    let text: String
    let imageName: String

    var body: some View {
        Label {
            Text(text)
        } icon: {
            Image(imageName, bundle: .module)
        }
    }
}

extension View {
    func navTabItem(destination: TopLevelDestination) -> some View {
        self.tabItem {
            NavTabView(text: destination.title, imageName: destination.imageName)
        }
    }
}

public struct MainView: View {
    public init() {}

    public var body: some View {
        TabView {
            CasesView()
                .navTabItem(destination: .cases)
            MenuView()
                .navTabItem(destination: .menu)
        }
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}
