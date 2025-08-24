//
//  FirstUseView.swift
//  NiuNiuVideoLearning
//
//  Created by Chengzhi 张 on 2025/8/24.
//

import SwiftUI

struct FirstUseView: View {
    @AppStorage("firstUse") private var firstUse = true
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack{
            Image(systemName: "sparkles")
                .foregroundStyle(.blue)
                .font(.system(size: 46))
                .padding(.top)
            Text("欢迎使用牛牛看课")
                .font(.largeTitle)
            
            VStack(alignment: .leading, spacing: 16){
                HStack{
                    Image(systemName: "video.fill")
                        .foregroundStyle(.blue)
                        .font(.largeTitle)
                    VStack(alignment: .leading){
                        Text("观看课程视频")
                            .bold()
                        Text("自由更改播放速度与结束时间预测")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                HStack{
                    Image(systemName: "folder.fill")
                        .foregroundStyle(.orange)
                        .font(.largeTitle)
                    VStack(alignment: .leading){
                        Text("创建课程集")
                            .bold()
                        Text("为每一科课程创建课程集")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                HStack{
                    Image(systemName: "eye.fill")
                        .foregroundStyle(.pink)
                        .font(.largeTitle)
                    VStack(alignment: .leading){
                        Text("自由续看")
                            .bold()
                        Text("自动记录播放位置与自动续播")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 20)
            
            Divider()
            
            HStack{
                Spacer()
                
                Button("继续"){
                    firstUse = false
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.top, 5)
        }
        .padding()
        .frame(width: 550)
    }
}

#Preview {
    FirstUseView()
}
