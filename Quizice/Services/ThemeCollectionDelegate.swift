import UIKit

protocol ThemeCollectionDelegate: AnyObject {
    func themeButtonTouchedDown(_ sender: UIButton)
    func themeButtonTouchedUpInside(_ sender: UIButton, themeID: String)
    func themeButtonTouchedUpOutside(_ sender: UIButton)
    func aiThemeButtonTouchedUpInside(_ sender: UIButton)
    func feelingLuckyButtonTouchedUpInside(_ sender: UIButton)
    func statisticsButtonTouchedUpInside(_ sender: UIButton)
}
