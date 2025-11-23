// entry/src/main/ets/pages/DdlPage.ets

import DdlList from '../components/deadline/DdlList';

@Component
export default struct DdlPage {
  build() {
    // 页面只负责渲染这个组件
    DdlList();
  }
}
