//
//  AddCollectionView.swift
//  NiuNiuVideoLearning
//
//  Created by Chengzhi 张 on 2025/8/23.
//

import SwiftUI

struct AddCollectionView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var collectionName = ""
    @State private var collectionNote = ""
    @State private var selectedTag: Int = 0
    
    @State private var showAlert = false
    @State private var alertInfo = ""
    
    var body: some View {
        VStack{
            HStack{
                Text("新建课程视频集")
                    .font(.title2)
                    .bold()
                    .padding(.bottom)
                
                Spacer()
            }
            
            HStack{
                Text("名称：")
                Spacer()
                TextField("请输入课程名称...", text: $collectionName)
            }
            
            HStack{
                Text("备注：")
                Spacer()
                TextField("可输入备注...", text: $collectionNote)
            }
            
            HStack{
                Text("标签：")
                Spacer()
                Picker("", selection: $selectedTag) {
                    ForEach(tags.indices, id: \.self) { index in
                        Text(tags[index].name)
                            .tag(index)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
            
            Divider()
                .padding(.vertical)
            
            HStack{
                Spacer()
                
                Button("取消"){
                    presentationMode.wrappedValue.dismiss()
                }
                
                Button("添加"){
                    if collectionName.isEmpty {
                        alertInfo = "请输入课程名称"
                        showAlert = true
                        
                        return
                    }
                    
                    addCollection(name: collectionName, note: collectionNote, tag: Int64(selectedTag), in: viewContext)
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(.borderedProminent)
                .foregroundStyle(.secondary)
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
    AddCollectionView()
}
