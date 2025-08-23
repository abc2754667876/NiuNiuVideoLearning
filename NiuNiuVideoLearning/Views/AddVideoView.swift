//
//  AddVideoView.swift
//  NiuNiuVideoLearning
//
//  Created by Chengzhi 张 on 2025/8/23.
//

import SwiftUI

struct AddVideoView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var showAlert = false
    @State private var alertInfo = ""
    
    @State private var selectedName: String = "请选择"
    @State private var selectedID: UUID? = nil
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Collections.date, ascending: false)],
        animation: .default
    )
    private var collections: FetchedResults<Collections>
    
    var body: some View {
        VStack{
            HStack{
                Text("导入视频到课程")
                    .font(.title2)
                    .bold()
                    .padding(.bottom)
                
                Spacer()
            }
            
            HStack{
                Text("课程：")
                Spacer()
                Picker("", selection: $selectedID) {
                    Text("请选择").tag(UUID?.none)

                    ForEach(collections) { item in
                        Text(item.name?.isEmpty == false ? item.name! : "未命名")
                            .tag(item.id)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .onChange(of: selectedID) { newValue in
                    if let id = newValue,
                       let found = collections.first(where: { $0.id == id }) {
                        selectedName = (found.name?.isEmpty == false) ? found.name! : "未命名"
                    } else {
                        selectedName = "请选择"
                    }
                }
            }
            
            HStack(alignment: .top){
                Text("视频：")
                    .font(.title2)
                    .bold()
                    .padding(.bottom)
                
                Spacer()
            }
            
            Divider()
                .padding(.vertical)
            
            HStack{
                Button("选择视频..."){
                    
                }
                .buttonStyle(.borderedProminent)
                
                Spacer()
                
                Button("取消"){
                    presentationMode.wrappedValue.dismiss()
                }
                
                Button("添加"){
                    if selectedID == nil {
                        alertInfo = "请选择要加入的课程集"
                        showAlert = true
                        
                        return
                    }
                    
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            
        }
        .frame(width: 350)
        .padding()
        .alert("提示", isPresented: $showAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(alertInfo)
        }
    }
}

#Preview {
    AddVideoView()
}
