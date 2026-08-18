import SwiftUI

/// The row shown for a Fight in a list.
///
/// Lives in its own file because two screens draw it — `FightListView` and
/// `SavedFightsView` — so a change here is visible in both. Keeping it inside
/// the list view hid that fact and made the diff for a card tweak look like a
/// diff for the whole page.
struct FightCard: View {
    let fight: Fight
    var isSaved = false
    var hasAttended = false
    /// Set only for the organiser of this Fight, so a draft is obviously not public yet.
    var hostStatus: Fight.Status?
    
    var body: some View {
        HStack(spacing: 0) {
            Capsule()
                .fill(fight.category.accentColor)
                .frame(width: 6, height: 68)
                .padding(.trailing, 10)
            
            thumbnail
                .padding(.trailing, 14)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(fight.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Tokens.Semantic.text)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(FightFormat.shortWhen(fight))
                    .font(.system(size: 13))
                    .foregroundStyle(Tokens.Semantic.footnote)
                    
            }
            
            Spacer(minLength: 8)
            
            Image(systemName: "chevron.right")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Tokens.Semantic.text)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Tokens.Palette.white)
                .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 3)
        )
    }
    
    
    private var thumbnail: some View {
        ZStack(alignment: .bottomTrailing) {
            photo
                .frame(width: 110, height: 68)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            
            Image(fight.category.mascotName)
                .resizable()
                .scaledToFit()
                .frame(width: 36, height: 36)
                .offset(x: 10, y: 8)
        }
    }
    
    @ViewBuilder
    private var photo: some View {
        if let name = fight.imageName {
            Image(name)
                .resizable()
                .scaledToFill()
        } else {
            // Hanya warna pucat, tanpa ikon: asset *-icon ternyata karakter
            // yang sama dengan maskotnya, jadi keduanya tampil kembar.
            // Maskot yang menumpuk sudah cukup jadi penanda kategori.
            Rectangle()
                .fill(fight.category.cardBackground)
        }
    }
}

#Preview("Card") {
    VStack(spacing: 12) {
        FightCard(fight: MockFightData.seeded[0])
        FightCard(fight: MockFightData.seeded[1])
        FightCard(fight: MockFightData.seeded[2])
        FightCard(fight: MockFightData.seeded[3])
        FightCard(fight: MockFightData.seeded[4])
        FightCard(fight: MockFightData.seeded[5])
    }
    .padding()
    .background(Tokens.Palette.white)
}
