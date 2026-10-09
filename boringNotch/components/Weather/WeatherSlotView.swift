//
//  WeatherSlotView.swift
//  Dino
//
//  Created for Dino Architecture Evolution.
//

import SwiftUI

public struct WeatherClosedPillView: View {
    public var temperature: String = "25°"
    public var iconName: String = "sun.max.fill"
    public var iconColor: Color = .yellow
    
    public init(temperature: String = "25°", iconName: String = "sun.max.fill", iconColor: Color = .yellow) {
        self.temperature = temperature
        self.iconName = iconName
        self.iconColor = iconColor
    }
    
    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(iconColor)
            
            Spacer(minLength: 0)
            
            Text(temperature)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 8)
    }
}

public struct DailyForecastItem: Identifiable, Sendable {
    public let id = UUID()
    public let day: String
    public let icon: String
    public let iconColor: Color
    public let temp: String
}

public struct WeatherExpandedCardView: View {
    public var cityName: String = "Jizzakh"
    public var currentTemp: String = "25°"
    public var condition: String = "Clear"
    public var highLow: String = "H:25° L:13°"
    
    public let forecast: [DailyForecastItem] = [
        DailyForecastItem(day: "Sat", icon: "sun.max.fill", iconColor: .yellow, temp: "24°"),
        DailyForecastItem(day: "Sun", icon: "cloud.fill", iconColor: .white.opacity(0.8), temp: "26°"),
        DailyForecastItem(day: "Mon", icon: "cloud.rain.fill", iconColor: .cyan, temp: "19°"),
        DailyForecastItem(day: "Tue", icon: "cloud.rain.fill", iconColor: .cyan, temp: "21°"),
        DailyForecastItem(day: "Wed", icon: "sun.max.fill", iconColor: .yellow, temp: "23°")
    ]
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 14) {
            // Header Row
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(cityName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(currentTemp)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 3) {
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.yellow)
                    
                    Text(condition)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                    
                    Text(highLow)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            Divider()
                .background(Color.white.opacity(0.2))
            
            // 5-Day Forecast Row
            HStack(spacing: 12) {
                ForEach(forecast) { item in
                    VStack(spacing: 6) {
                        Text(item.day)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                        
                        Image(systemName: item.icon)
                            .font(.system(size: 14))
                            .foregroundColor(item.iconColor)
                            .frame(height: 18)
                        
                        Text(item.temp)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .frame(width: 360, height: 145)
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.85), Color.indigo.opacity(0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
