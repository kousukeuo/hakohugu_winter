<template>
  <div id="app">
    <div class="form-row mb-md-3">
      <div class="col">
        <input type="text" class="form-control" id="Input" v-model="title">
      </div>
      <div class="col">
        <button v-if="test_flag" type="button" class="btn btn-success" @click="endTest">テストを終了</button>
        <button v-else type="button" class="btn btn-success" @click="saveNote">ノートを保存</button>
        <span class="ml-3">{{auto_save_text}}</span>
      </div>
    </div>

    <div class="nav-col">
      <ul class="nav nav-tabs">
        <li class="nav-item">
          <a
            href="#tab1"
            @click="viewChange"
            class="nav-link"
            v-bind:class="{ active: tab1 }"
            data-toggle="tab"
          >質問に答える</a>
        </li>
        <li class="nav-item">
          <a
            href="#tab2"
            @click="viewChange"
            class="nav-link"
            v-bind:class="{ active: tab2 }"
            data-toggle="tab"
          >回答の編集</a>
        </li>
      </ul>
    </div>

    <div>
      <div class="text-right">
        <p>{{getNowQuestion}}</p>
      </div>
    </div>

    <div class="tab-content">
      <div id="tab1" class="tab-pane" v-bind:class="{ active: tab1 }">
        <div id="conversation">
          <template v-if="questions" v-for="conversationLog in conversationLogs">
            <div class="kaiwa">
              <figure class="kaiwa-img-left">
                <img :src="image_path1" alt="no-img2">
                <!-- <figcaption class="kaiwa-img-description">{{temp_title}}</figcaption> -->
              </figure>
              <div class="kaiwa-text-right">
                <p class="kaiwa-text" v-html="conversationLog.question"></p>
              </div>
            </div>

            <div v-if="conversationLog.answer" class="kaiwa">
              <figure class="kaiwa-img-right">
                <img :src="image_path2" alt="no-img2">
                <figcaption class="kaiwa-img-description">{{user_name}}</figcaption>
              </figure>
              <div class="kaiwa-text-left">
                <p class="kaiwa-text">{{conversationLog.answer}}</p>
              </div>
            </div>
          </template>
        </div>

        <div id="inputText">
          <textarea
            @keyup.ctrl.enter="transmissionMessage"
            @keyup.ctrl.space="skipQuestion"
            v-model="answer"
            placeholder="解答を入力"
            style="width:100%;height:90%;"
          ></textarea>
        </div>

        <!-- 回答ボタンの横に次の質問へスキップするボタンを追加 -->
        <div id="transmission">
          <div class="transmissionBox">
            <div class="row">
              <div id="transmissionMessage" v-bind:class="toggleSize" class="messageBox-col">
                <button
                  @click="transmissionMessage"
                  type="button"
                  class="btn btn-success btn-block"
                >回答</button>
              </div>
              <div id="skipQuestion" class="col-sm-2 skipBox-col">
                <button @click="skipQuestion" type="button" class="btn btn-info btn-block">スキップ</button>
              </div>

              <!-- ブラウザがChromeのときのみ音読ボタンを表示 -->
              <div id="recordButton" v-if="chrome" class="col-sm-1 readButton-col">
                <template v-if="read_flag">
                  <button
                    class="btn btn-secondary btn-block"
                    title="質問の音読を終了"
                    @click="read_flag = false"
                  >
                    <i class="fa fa-volume-up"></i>
                  </button>
                </template>
                <template v-else>
                  <button
                    class="btn btn-secondary btn-block"
                    title="質問の音読を開始"
                    @click="read_flag = true"
                  >
                    <i class="fa fa-volume-off"></i>
                  </button>
                </template>
              </div>

              <!-- ブラウザがChromeのときのみ音声入力を表示 -->
              <div id="recordButton" v-if="chrome" class="col-sm-1 recordButton-col">
                <template v-if="record_flag">
                  <button class="btn btn-secondary btn-block" title="音声入力を終了" @click="stop">
                    <i class="fa fa-microphone"></i>
                  </button>
                </template>
                <template v-else>
                  <button class="btn btn-secondary btn-block" title="音声入力を開始" @click="record">
                    <i class="fa fa-microphone-slash"></i>
                  </button>
                </template>
              </div>
            </div>
            <textarea class="form-control" v-if="record_flag" v-model="temp"></textarea>
          </div>
        </div>
      </div>
      <div id="tab2" class="tab-pane" v-bind:class="{ active: tab2 }">
        <textarea id="MyID"></textarea>
      </div>
    </div>
  </div>
</template>


<script>
import axios from "axios";
import SimpleMDE from "simplemde";
import { csrfToken } from "rails-ujs";
import swal from "sweetalert";

//axiosでPOSTを送るときのCSRF対策のトークンをrails-ujsを使って作成
axios.defaults.headers.common["X-CSRF-Token"] = csrfToken();
var simplemde;

try {
  //音声認識APIの使用
  var recognition = new webkitSpeechRecognition();
  //言語を日本語に設定
  recognition.lang = "ja";
  recognition.interimResults = true;
  recognition.continuous = true;
} catch (error) {
  console.log("エラー内容：" + error);
}

export default {
  data: () => {
    return {
      title: "",
      answer: "",
      temp: "",
      note: "",
      questions: "",
      image_path1: "",
      image_path2: "",
      count: 0,
      count_t: 0, //チュートリアル用カウント変数
      count_d: 0, //詳細を出す時のカウント変数
      count_e: 0, //例を出す時のカウント変数
      count_h: 0, //ヘルプ用
      count_called_h: 0,
      sum_h: 0,
      conversationLogs: [],
      tutorials: [
        ``,
        `質問をするので、答えが書けたら「回答」ボタンで送信してください<br>
        ・回答を見直したい、編集したい　→　「回答の編集」タブ<br>
        ・質問に答えず次に進みたい　　　→　「スキップ」ボタン<br>
        ・質問の意味がわからない　　　　→　「詳しく」と入力<br>
        ・回答例を見たい　　　　　　　　→　「例えば」と入力<br>
        ・使い方をもう一度確認したい　　→　「ヘルプ」と入力<br>
          <br>
          準備はいいですか？<br>
          それでは、最初の質問をします。「回答」ボタンをクリックしてください`
      ],
      helps: [
        `アシスタントが質問をするので、書けたら「回答」ボタンで送信してください<br>
        <br>
        ・回答を見直したい、編集したい　→　「回答の編集」タブ<br>
        ・質問に答えず次に進みたい　　　→　「スキップ」ボタン<br>
        ・質問の意味がわからない　　　　→　「詳しく」と入力<br>
        ・回答例を見たい　　　　　　　　→　「例えば」と入力<br>
        ・使い方をもう一度確認したい　　→　「ヘルプ」と入力<br>
        <br>
        準備はいいですか？<br>
        それでは、先ほどの質問から再開します。「回答」ボタンをクリックしてください`
      ],
      tutorial_flag: true,
      help_flag: false,
      tab1: true,
      tab2: false,
      record_flag: false,
      chrome: false,
      test_flag: false,
      read_flag: false,
      auto_save_text: ""
    };
  },

  mounted: function() {
    let test = this.getParams().test;
    if (test == 1) {
      this.test_flag = true;
    }
    let path = location.pathname.split("/");
    let documentNumber = path[2];
    axios
      .get(`/api/questions/${documentNumber}`)
      .then(res => {
        let that = this;
        return this.storeResponseInVue(res, that);
      })
      .then(stored => {
        let that = this;
        return this.new_MDE(that);
      })
      .then(MEDCreated => {
        let that = this;
        simplemde.codemirror.on("change", function() {
          that.note = simplemde.value();
        });
        this.checkBrowser();
        setInterval(() => {
          this.autoSave();
        }, 10000);
      });
  },

  computed: {
    getNowQuestion: function() {
      if (this.count + 1 < this.questions.length) {
        return `現在${this.count + 1}/${this.questions.length}問目`;
      } else {
        return `現在${this.questions.length}/${this.questions.length}問目`;
      }
    },
    toggleSize: function() {
      if (this.chrome) {
        return "col-sm-8";
      } else {
        return "col-sm-10";
      }
    }
  },

  methods: {
    //mounted のときに呼ばれる関数1
    storeResponseInVue: function(res, that) {
      return new Promise(function(resolve) {
        that.questions = res.data.questions;
        that.title = res.data.title;
        that.temp_title = res.data.temp_title;
        that.note = res.data.content;
        that.count = res.data.question_number;
        that.count_t = res.data.count_t;
        that.count_d = res.data.count_d;
        that.count_e = res.data.count_e;
        that.count_called_h = res.data.count_called_h;
        that.sum_h = res.data.sum_h;
        that.image_path1 = res.data.image_path1;
        that.image_path2 = res.data.image_path2;
        that.user_name = res.data.user_name;
        that.conversationLogs = JSON.parse(res.data.conversation_logs);
        that.tutorials[0] =
          "こんにちは、" +
          res.data.temp_title +
          "です。<br>" +
          "・今すぐ会話を始める　→　「スキップ」ボタン<br>" +
          "・使い方を確認　　　　→　「回答」ボタン";
        if (that.note == null) {
          that.note = "";
        }

        if (that.conversationLogs == null) {
          that.conversationLogs = [];
          that.conversationLogs.push({
            question: that.tutorials[0]
          });
        } else {
          that.tutorial_flag = false;
          that.tab1 = false;
          that.tab2 = true;
        }
        resolve();
      });
    },
    //mounted のときに呼ばれる関数2
    new_MDE: function(that) {
      return new Promise(function(resolve) {
        simplemde = new SimpleMDE({
          element: document.getElementById("MyID"),
          initialValue: that.note,
          toolbar: [
            "bold",
            "italic",
            "heading",
            "|",
            "quote",
            "unordered-list",
            "ordered-list",
            "|",
            "link",
            "image",
            "|",
            "preview",
            "guide"
          ],
          forceSync: true, //エディタの入力値をdocument.getElementById("MyID").valueで取得できるようになる
          autofocus: true //エディタに自動フォーカスする
        });
        resolve();
      });
    },
    getParams: function() {
      var vars = {};
      var param = location.search.substring(1).split("&");
      for (var i = 0; i < param.length; i++) {
        var keySearch = param[i].search(/=/);
        var key = "";
        if (keySearch != -1) key = param[i].slice(0, keySearch);
        var val = param[i].slice(param[i].indexOf("=", 0) + 1);
        if (key != "") vars[key] = decodeURI(val);
      }
      return vars;
    },
    addAnswerToNote: function() {
      this.note +=
        ` Q${this.count + 1}` + "  " + this.questions[this.count].qtext + "\n";
      this.note += `  ## ${this.answer}` + "\n";
      simplemde.value(this.note);
      setTimeout(function() {
        simplemde.codemirror.refresh();
      }, 1);
    },
    transmissionMessage: function() {
      //会話ログに解答を格納
      if (this.questions[this.count]) {
        this.$set(
          this.conversationLogs[
            this.count_t +
              this.count +
              this.count_d +
              this.count_e +
              this.sum_h +
              this.count_called_h
          ],
          "answer",
          this.answer
        );
        /*  this.speakQuestion(this.answer); */
      }
      //チュートリアル中と本番の質問で場合分け
      if (this.tutorial_flag && this.count_t < this.tutorials.length) {
        //チュートリアル中は回答をノートに記録しない
        this.count_t += 1;
      } else if (this.help_flag && this.count_h < this.helps.length) {
        this.count_h += 1;
        this.sum_h += 1;
      } else {
        this.tutorial_flag = false;
        this.help_flag = false;
        //特殊回答による分岐
        if (this.answer == "詳しく" || this.answer == "くわしく") {
          //詳しくorくわしくで詳細を表示
          this.conversationLogs.push({
            question:
              "【質問意図・答え方】" + this.questions[this.count].qdetail
          });
          this.answer = "";
          this.count_d += 1;
          this.$nextTick(function() {
            this.scrollToEnd("#conversation");
          });
          return false;
        } else if (this.answer == "例えば" || this.answer == "たとえば") {
          //例えばorたとえばで例を表示
          this.conversationLogs.push({
            question: "【答え方の例】" + this.questions[this.count].example
          });
          this.answer = "";
          this.count_e += 1;
          this.$nextTick(function() {
            this.scrollToEnd("#conversation");
          });
          return false;
        } else if (this.answer == "ヘルプ") {
          this.count_called_h += 1;
          this.count_h = 0;
          this.help_flag = true;
          this.conversationLogs.push({
            question: this.helps[this.count_h]
          });
          this.answer = "";
          this.$nextTick(function() {
            this.scrollToEnd("#conversation");
          });
          return false;
        } else {
          this.addAnswerToNote();
          this.answer = "";
          //次の質問に進める。
          this.count += 1;
        }
      }
      //次の質問を会話ログに格納
      if (this.questions[this.count]) {
        if (this.tutorial_flag && this.count_t < this.tutorials.length) {
          this.conversationLogs.push({
            question: this.tutorials[this.count_t]
          });
        } else if (this.help_flag && this.count_h < this.helps.length) {
          this.conversationLogs.push({
            question: this.helps[this.count_h]
          });
        } else {
          this.tutorial_flag = false;
          this.help_flag = false;
          //遅延処理
          this.conversationLogs.push({
            question: "..."
          });
          setTimeout(() => {
            this.conversationLogs.pop();
          }, 500);
          setTimeout(() => {
            this.conversationLogs.push({
              question: this.questions[this.count].qtext
            });
          }, 500);
          this.speakQuestion(this.questions[this.count].qtext);
        }
      }

      if (this.questions.length == this.count) {
        this.conversationLogs.push({
          question:
            "この質問で終わりです、回答の編集タブを押して自分の回答を確認してみましょう。"
        });
      }
      /* スクロール位置を更新*/
      this.$nextTick(function() {
        this.scrollToEnd("#conversation");
      });
    },
    /*質問を飛ばす時に行う処理*/
    addSkipQuestionToNote: function() {
      this.note +=
        ` Q${this.count + 1}` + "  " + this.questions[this.count].qtext + "\n";
      this.note += "\t" + "" + "\n";
      simplemde.value(this.note);
      setTimeout(function() {
        simplemde.codemirror.refresh();
      }, 1);
    },
    skipQuestion: function() {
      if (this.tutorial_flag) {
        //チュートリアル中に押されたら、チュートリアルを中止
        this.tutorial_flag = false;
        this.count_t += 1;
      } else if (this.help_flag) {
        //ヘルプ中に押されたら、ヘルプを中止
        this.help_flag = false;
        this.count_h += 1;
        this.sum_h += 1;
      } else {
        //会話ログに「次の質問」と格納
        if (this.questions[this.count]) {
          this.$set(
            this.conversationLogs[
              this.count_t +
                this.count +
                this.count_d +
                this.count_e +
                this.sum_h +
                this.count_called_h
            ],
            "answer",
            "次の質問は?"
          );
        }
        this.addSkipQuestionToNote();
        this.answer = "";
        //次の質問に進める。
        this.count += 1;
      }

      if (this.questions[this.count]) {
        //遅延処理
        this.conversationLogs.push({
          question: "..."
        });
        setTimeout(() => {
          this.conversationLogs.pop();
        }, 500);
        setTimeout(() => {
          this.conversationLogs.push({
            question: this.questions[this.count].qtext
          });
        }, 500);
        this.speakQuestion(this.questions[this.count].qtext);
      }

      if (this.questions.length == this.count) {
        this.conversationLogs.push({
          question: "この質問で終わりです"
        });
      }

      /* スクロール位置を更新*/
      this.$nextTick(function() {
        this.scrollToEnd("#conversation");
      });
    },
    /*質問飛ばす処理ここまで*/

    scrollToEnd: function(query) {
      var container = document.querySelector(query);
      container.scrollTop = container.scrollHeight;
    },
    viewChange: function() {
      setTimeout(function() {
        simplemde.codemirror.refresh();
      }, 1);
      /* スクロール位置を更新*/
      this.$nextTick(function() {
        this.scrollToEnd("#conversation");
      });
    },
    saveNote: function() {
      let document = this.note;
      axios
        .patch("", {
          title: this.title,
          content: document,
          conversation_logs: JSON.stringify(this.conversationLogs),
          question_number: this.count,
          count_t: this.count_t,
          count_d: this.count_d,
          count_e: this.count_e,
          count_called_h: this.count_called_h,
          sum_h: this.sum_h
        })
        .then(function(response) {
          swal("Complete!", "ノートの保存が完了しました。", "success");
        })
        .catch(error => {
          swal(
            "Oops!",
            "ノートの保存に失敗しました。もう一度お試しください",
            "error"
          );
        });
    },
    autoSave: function() {
      let document = this.note;
      axios.patch("", {
        title: this.title,
        content: document,
        conversation_logs: JSON.stringify(this.conversationLogs),
        question_number: this.count,
        count_t: this.count_t,
        count_d: this.count_d,
        count_e: this.count_e,
        count_called_h: this.count_called_h,
        sum_h: this.sum_h
      });
      var date = new Date();
      var year = date.getFullYear();
      var month = date.getMonth() + 1;
      var day = date.getDate();
      var hour = date.getHours();
      var minute = date.getMinutes();
      var second = date.getSeconds();

      this.auto_save_text =
        "自動保存しました  " +
        year +
        "/" +
        month +
        "/" +
        day +
        "  " +
        hour +
        "時" +
        minute +
        "分" +
        second +
        "秒";
    },
    record: function() {
      var that = this;

      this.record_flag = true;
      // 音声認識をスタート
      recognition.start();

      recognition.onresult = function(event) {
        var results = event.results;
        for (var i = event.resultIndex; i < results.length; i++) {
          if (results[i].isFinal) {
            that.answer += results[i][0].transcript;
          } else {
            that.temp = results[i][0].transcript;
          }
        }
      };
    },
    stop: function() {
      this.record_flag = false;
      recognition.stop();
    },
    checkBrowser: function() {
      var agent = window.navigator.userAgent.toLowerCase();

      if (agent.indexOf("msie") > -1) {
      } else if (agent.indexOf("edge") > -1) {
      } else if (agent.indexOf("chrome") > -1) {
        this.chrome = true;
      } else if (agent.indexOf("safari") > -1) {
      } else if (agent.indexOf("firefox") > -1) {
      } else {
      }
    },
    endTest: function() {
      let path = location.pathname.split("/");
      let documentNumber = path[2];
      var form = document.createElement("form");

      form.method = "POST";
      form.action = `/documents/${documentNumber}/test`;

      document.body.appendChild(form);

      form.submit();
    },
    speakQuestion: function(text) {
      if (this.read_flag == true) {
        // 発言を作成
        const uttr = new SpeechSynthesisUtterance(text);
        // 発言を再生 (発言キューに発言を追加)
        speechSynthesis.speak(uttr);
      }
    }
  }
};
</script>
